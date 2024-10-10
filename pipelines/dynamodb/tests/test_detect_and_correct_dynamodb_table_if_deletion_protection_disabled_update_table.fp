pipeline "test_detect_and_correct_dynamodb_table_if_deletion_protection_disabled_update_table" {
  title       = "Test Create DynamoDB DynamoDB Table Deletion Protection Disabled"
  description = "Test the detect_and_correct_dynamodb_table_if_deletion_protection_disabled pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "region" {
    type        = string
    description = local.description_region
    default    = "us-east-1"

  }

  param "table_name" {
    type        = string
    description = "The name of the table."
    default     = "flowpipe-test-${uuid()}"
  }

  step "container" "create_dynamodb_table" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "dynamodb", "create-table",
      "--table-name", param.table_name,
      "--attribute-definitions", "AttributeName=name,AttributeType=S",
      "--key-schema", "AttributeName=name,KeyType=HASH",
      "--provisioned-throughput", "ReadCapacityUnits=5,WriteCapacityUnits=5"
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "sleep" "sleep_150_seconds" {
    depends_on = [ step.container.create_dynamodb_table ]
    duration   = "100s"
  }

  step "pipeline" "respond" {
    depends_on = [step.sleep.sleep_150_seconds]
    pipeline = pipeline.detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled
    args = {
      default_action     = "update_table"
      enabled_actions    = ["update_table"]
    }
  }

  step "sleep" "sleep_50_seconds" {
    depends_on = [ step.pipeline.respond ]
    duration   = "50s"
  }

  step "query" "get_dynamodb_table" {
    depends_on = [step.sleep.sleep_50_seconds]
    database = var.database
    sql = <<-EOQ
      select
        *
      from
        aws_dynamodb_table
      where
        name = '${param.table_name}'
        and deletion_protection_enabled;
    EOQ
  }

  step "container" "disable_deletion_protection" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.query.get_dynamodb_table]

    cmd = [
      "dynamodb", "update-table",
      "--table-name", param.table_name,
      "--no-deletion-protection-enabled"
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "pipeline" "delete_dynamodb_table" {
    depends_on = [step.container.disable_deletion_protection]
    pipeline = aws.pipeline.delete_dynamodb_table
    args = {
      table_name  = param.table_name
      region      = param.region
      cred        = param.cred
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_dynamodb_table" = !is_error(step.container.create_dynamodb_table) ? "pass" : "fail: ${error_message(step.container.create_dynamodb_table)}"
      "get_dynamodb_table" = length(step.query.get_dynamodb_table.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "disable_deletion_protection" = !is_error(step.container.disable_deletion_protection) ? "pass" : "fail: ${error_message(step.container.disable_deletion_protection)}"
      "delete_dynamodb_table" = !is_error(step.pipeline.delete_dynamodb_table) ? "pass" : "fail: ${error_message(step.pipeline.delete_dynamodb_table)}"
    }
  }

}