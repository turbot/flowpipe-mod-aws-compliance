pipeline "test_detect_and_correct_s3_buckets_without_ssl_enforcement_enforce_ssl" {
  title       = "Test Detect and Correct S3 Buckets if Publicly Accessible - Enforce SSL"
  description = "Test the enforce SSL action for S3 buckets."

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

  param "bucket" {
    type        = string
    description = "The name of the bucket."
    default     = "flowpipe-test-${uuid()}"
  }

  step "transform" "base_args" {
    output "base_args" {
      value = {
        bucket = param.bucket
        conn   = param.conn
        region = param.region
      }
    }
  }

  step "pipeline" "create_s3_bucket" {
    pipeline = aws.pipeline.create_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  // step "pipeline" "run_detection_skip" {
  //   depends_on = [step.pipeline.create_s3_bucket]
  //   pipeline   = pipeline.detect_and_correct_s3_buckets_without_ssl_enforcement
  //   args = {
  //     default_action   = "skip"
  //     enabled_actions  = ["skip"]
  //   }
  // }

  // step "query" "verify_skip" {
  //   depends_on = [step.pipeline.run_detection]
  //   database   = var.database
  //   sql = <<-EOQ
  //     with ssl_ok as (
  //       select
  //         distinct name,
  //         arn,
  //         'ok' as status
  //       from
  //         aws_s3_bucket,
  //         jsonb_array_elements(policy_std -> 'Statement') as s,
  //         jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p,
  //         jsonb_array_elements_text(s -> 'Action') as a,
  //         jsonb_array_elements_text(s -> 'Resource') as r,
  //         jsonb_array_elements_text(
  //           s -> 'Condition' -> 'Bool' -> 'aws:securetransport'
  //         ) as ssl
  //       where
  //         p = '*'
  //         and s ->> 'Effect' = 'Deny'
  //         and ssl :: bool = false
  //     )
  //     select
  //       concat(b.name, ' [', b.region, '/', b.account_id, ']') as title,
  //       b.name as bucket_name,
  //       b.sp_connection_name as conn,
  //       b.region
  //     from
  //       aws_s3_bucket as b
  //       left join ssl_ok as ok on ok.name = b.name
  //     where
  //       ok.name is null
  //       and b.name = '${param.bucket}';
  //   EOQ
  // }

  // output "result_verify_skip" {
  //   description = "Result of enable SSL action verification - Skip."
  //   value       = length(step.query.verify_enforce_ssl.rows) == 1 ? "pass" : "fail: ${error_message(step.pipeline.run_detection)}"
  // }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = pipeline.correct_one_s3_bucket_without_ssl_enforcement
    args = {
      title            = param.bucket
      bucket_name      = param.bucket
      conn             = param.conn
      region           = param.region
      approvers        = []
      default_action   = "enforce_ssl"
      enabled_actions  = ["enforce_ssl"]
    }
  }

  step "query" "verify_enforce_ssl" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql = <<-EOQ
      with ssl_ok as (
        select
          distinct name,
          arn,
          'ok' as status
        from
          aws_s3_bucket,
          jsonb_array_elements(policy_std -> 'Statement') as s,
          jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p,
          jsonb_array_elements_text(s -> 'Action') as a,
          jsonb_array_elements_text(s -> 'Resource') as r,
          jsonb_array_elements_text(
            s -> 'Condition' -> 'Bool' -> 'aws:securetransport'
          ) as ssl
        where
          p = '*'
          and s ->> 'Effect' = 'Deny'
          and ssl :: bool = false
      )
      select
        concat(b.name, ' [', b.region, '/', b.account_id, ']') as title,
        b.name as bucket_name,
        b.sp_connection_name as conn,
        b.region
      from
        aws_s3_bucket as b
        left join ssl_ok as ok on ok.name = b.name
      where
        ok.name is not null
        and b.name = '${param.bucket}';
    EOQ
  }

  step "pipeline" "delete_s3_bucket" {
    # Don't run before we've had a chance to list buckets
    depends_on = [step.query.verify_enforce_ssl]

    pipeline = aws.pipeline.delete_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  output "bucket" {
    description = "Bucket name used in the test."
    value       = param.bucket
  }

  output "result_enforce_ssl" {
    description = "Result of enable SSL action verification."
    value       = length(step.query.verify_enforce_ssl.rows) == 1 ? "pass" : "fail: ${error_message(step.pipeline.run_detection)}"
  }
}
