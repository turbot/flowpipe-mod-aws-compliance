pipeline "test_detect_and_correct_s3_buckets_without_ssl_enforcement_enforce_ssl" {
  title       = "Test detect and correct S3 buckets without SSL enforcement - enforce SSL"
  description = "Test the enforce SSL action for S3 buckets."
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

  step "query" "check_bucket_ssl_disabled" {
    database = var.database
    sql      = <<-EOQ
      with ssl_ok as (
        select
          distinct name,
          arn
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
          and ssl::bool = false
      )
      select
        concat(b.name, ' [', b.account_id, '/', b.region, ']') as title,
        b.name as bucket_name,
        b.sp_connection_name as conn,
        b.region
      from
        aws_s3_bucket as b
        left join ssl_ok as ok on ok.name = b.name
      where
        ok.name is null
        and b.name = '${param.bucket}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = pipeline.correct_one_s3_bucket_without_ssl_enforcement
    args = {
      title           = param.bucket
      bucket_name     = param.bucket
      conn            = param.conn
      region          = param.region
      approvers       = []
      default_action  = "enforce_ssl"
      enabled_actions = ["enforce_ssl"]
    }
  }

  step "query" "verify_enforce_ssl" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      with ssl_ok as (
        select
          distinct name,
          arn
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
          and ssl::bool = false
      )
      select
        concat(b.name, ' [', b.account_id, '/', b.region, ']') as title,
        b.name as bucket_name,
        b.sp_connection_name as conn,
        b.region
      from
        aws_s3_bucket as b
        left join ssl_ok as ok on ok.name = b.name
      where
        ok.name is null
        and b.name = '${param.bucket}';
    EOQ
  }

  step "pipeline" "delete_s3_bucket" {
    # Don't run before we've had a chance to list buckets
    depends_on = [step.query.verify_enforce_ssl]

    pipeline = aws.pipeline.delete_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  output "result_enforce_ssl" {
    description = "Result of enable SSL action verification."
    value       = length(step.query.verify_enforce_ssl.rows) == 0 ? "pass" : "fail: ${error_message(step.pipeline.run_detection)}"
  }
}
