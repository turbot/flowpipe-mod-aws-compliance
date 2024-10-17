pipeline "test_detect_and_correct_dynamodb_table_if_point_in_time_recovery_disabled_skip" {
  title       = "Test DynamoDB table point in time recovery disabled"
  description = "Test the detect_and_correct_dynamodb_table_if_point_in_time_recovery_disabled pipeline."

  tags = {
    type = "test"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
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

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "sleep" "sleep_100_seconds" {
    depends_on = [ step.container.create_dynamodb_table ]
    duration   = "100s"
  }

  step "pipeline" "run_detection" {
    depends_on = [step.sleep.sleep_100_seconds]
    pipeline = pipeline.detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled
    args = {
      database         = var.database
      notifier         = var.notifier
      notification_level = var.notification_level
      approvers          = var.approvers
      default_action     = "skip"
      enabled_actions    = ["skip"]
    }
  }

  step "query" "get_dynamodb_table" {
    depends_on = [step.pipeline.run_detection]
    database = var.database
    sql = <<-EOQ
      select
        arn
      from
        aws_dynamodb_table
      where
        name = '${param.table_name}'
        and lower( point_in_time_recovery_description ->> 'PointInTimeRecoveryStatus' ) = 'disabled';
    EOQ
  }

  step "pipeline" "delete_dynamodb_table" {
    depends_on = [step.query.get_dynamodb_table]
    pipeline = aws.pipeline.delete_dynamodb_table
    args = {
      table_name  = param.table_name
      region      = param.region
      conn        = param.conn
    }
  }

  output "get_dynamodb_table" {
    description = "Table name used in the test."
    value       = step.query.get_dynamodb_table
  }

  // // output "test_results" {
  // //   description = "Test results for each step."
  // //   value = {
  // //     "create_dynamodb_table" = !is_error(step.container.create_dynamodb_table) ? "pass" : "fail: ${error_message(step.container.create_dynamodb_table)}"
  // //     // "get_dynamodb_table"  = !is_error(step.pipeline.get_dynamodb_table) && length([for bucket in try(step.pipeline.list_s3_buckets.output.buckets, []) : bucket if bucket.Name == param.bucket]) > 0 ? "pass" : "fail: ${error_message(step.pipeline.get_dynamodb_table)}"
  // //     "delete_dynamodb_table" = !is_error(step.pipeline.delete_dynamodb_table) ? "pass" : "fail: ${error_message(step.pipeline.delete_dynamodb_table)}"
  // //   }
  // // }

}