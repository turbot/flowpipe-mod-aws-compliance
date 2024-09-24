pipeline "test_detect_and_correct_s3_buckets_if_publicly_accessible_skip" {
  title       = "Test Detect and Correct S3 Buckets if Publicly Accessible - Skip"
  description = "Test the skip action for publicly accessible S3 buckets."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
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
        cred   = param.cred
        region = param.region
      }
    }
  }

  step "pipeline" "create_public_s3_bucket" {
    pipeline = local.aws_pipeline_create_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_public_s3_bucket]
    pipeline   = pipeline.detect_and_correct_s3_buckets_with_public_access_enabled
    args = {
      database         = var.database
      notifier         = var.notifier
      notification_level = var.notification_level
      approvers        = var.approvers
      default_action   = "skip"
      enabled_actions  = ["skip"]
    }
  }

  step "query" "verify_skip" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql = <<-EOQ
      select 
        name
      from 
        aws_s3_bucket as bucket
      where 
        name = '${param.bucket}'
      -- and block_public_acls = false 
      -- and block_public_policy = false;
    EOQ
  }

  output "result" {
    description = "Result of skip action verification."
    value       = length(step.query.verify_skip.rows) == 1 ? "Bucket was skipped." : "Unexpected outcome."
  }

  output "results" {
    value = step.query.verify_skip
  }

  step "pipeline" "delete_s3_bucket" {
    # Don't run before we've had a chance to list buckets
    depends_on = [step.query.verify_skip]

    pipeline = local.aws_pipeline_delete_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  output "bucket" {
    description = "Bucket name used in the test."
    value       = param.bucket
  }
}
