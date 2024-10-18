pipeline "test_detect_and_correct_kms_keys_with_rotation_disabled_enable_key_rotation" {
  title       = "Test detect and correct KMS key with rotation disabled"
  description = "Test the detect_and_correct_kms_keys_with_rotation_disabled pipeline."

  tags = {
    folder = "Tests"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = "us-east-1"
  }

  step "container" "create_kms_key" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "kms", "create-key",
      "--key-usage", "ENCRYPT_DECRYPT",
      "--origin", "AWS_KMS", # Specifies AWS-managed origin
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "query" "get_kms_key_with_rotation_disabled" {
    depends_on = [step.container.create_kms_key]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(id, ' [', account_id, '/', region, ']') as title,
        id as key_id,
        region,
        sp_connection_name as conn
      from
        aws_kms_key
      where
        key_manager = 'CUSTOMER'
        and key_rotation_enabled = false
        and origin != 'EXTERNAL'
        and key_state not in ('PendingDeletion', 'Disabled')
        and id = '${jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId}';
    EOQ
  }

  step "pipeline" "run_detection" {
    if       = length(step.query.get_kms_key_with_rotation_disabled.rows) == 1
    pipeline = pipeline.correct_one_correct_kms_key_with_rotation_disabled

    args = {
      title           = step.query.get_kms_key_with_rotation_disabled.rows[0].title
      key_id          = step.query.get_kms_key_with_rotation_disabled.rows[0].key_id
      region          = step.query.get_kms_key_with_rotation_disabled.rows[0].region
      conn            = param.conn
      approvers       = []
      default_action  = "enable_key_rotation"
      enabled_actions = ["enable_key_rotation"]
    }
  }

  step "query" "get_kms_key_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        *
      from
        aws_kms_key
      where
        id = '${jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId}'
        and key_rotation_enabled = true
    EOQ
  }

  step "container" "delete_kms_key" {
    depends_on = [step.query.get_kms_key_after_detection]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "kms", "schedule-key-deletion",
      "--key-id", jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId,
      "--pending-window-in-days", "7"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_kms_key"              = !is_error(step.container.create_kms_key) ? "pass" : "fail: ${error_message(step.container.create_kms_key)}"
      "get_kms_key_after_detection" = length(step.query.get_kms_key_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_kms_key"              = !is_error(step.container.delete_kms_key) ? "pass" : "fail: ${error_message(step.container.delete_kms_key)}"
    }
  }
}

