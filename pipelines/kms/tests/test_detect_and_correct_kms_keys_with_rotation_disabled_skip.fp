pipeline "test_detect_and_correct_kms_keys_with_rotation_disabled_skip" {
  title       = "Test detect and_correct KMS key with rotation disabled"
  description = "Test the detect_and_correct_kms_keys_with_rotation_disabled pipeline."

  tags = {
    folder = "Tests"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
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

  step "pipeline" "run_detection" {
    depends_on = [step.container.create_kms_key]
    pipeline   = pipeline.detect_and_correct_kms_keys_with_rotation_disabled
    args = {
      default_action  = "skip"
      enabled_actions = ["skip"]
    }
  }

  step "query" "get_kms_key" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        *
      from
        aws_kms_key
      where
        id = '${jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId}'
        and key_rotation_enabled = false
    EOQ
  }

  step "container" "delete_kms_key" {
    depends_on = [step.query.get_kms_key]
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
      "create_kms_key" = !is_error(step.container.create_kms_key) ? "pass" : "fail: ${error_message(step.container.create_kms_key)}"
      "get_kms_key"    = length(step.query.get_kms_key.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_kms_key" = !is_error(step.container.delete_kms_key) ? "pass" : "fail: ${error_message(step.container.delete_kms_key)}"
    }
  }
}
