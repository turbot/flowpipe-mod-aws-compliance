pipeline "test_detect_and_correct_s3_buckets_with_public_access_enabled" {
  title       = "Test Detect and Correct S3 Buckets if Publicly Accessible - Block Public Access"
  description = "Test the block public access action for publicly accessible S3 buckets."
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
    default     = "us-east-1"
  }

  param "bucket" {
    type        = string
    description = "The name of the bucket."
    default     = "flowpipe-test-${uuid()}"
  }

  param "block_public_acls" {
    type        = bool
    description = "Specifies whether Amazon S3 should block public access control lists (ACLs) for this bucket and objects in this bucket."
    default     = false
  }

  param "ignore_public_acls" {
    type        = bool
    description = "Specifies whether Amazon S3 should ignore public ACLs for this bucket and objects in this bucket."
    default     = false
  }

  param "block_public_policy" {
    type        = bool
    description = "Specifies whether Amazon S3 should block public bucket policies for this bucket."
    default     = false
  }

  param "restrict_public_buckets" {
    type        = bool
    description = "Specifies whether Amazon S3 should restrict public bucket policies for this bucket."
    default     = false
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

  step "transform" "base_args_bucket_policy" {
    output "base_args" {
      value = {
        bucket = param.bucket
        conn   = param.conn
        region = param.region
        block_public_acls = param.block_public_acls
        ignore_public_acls = param.ignore_public_acls
        block_public_policy = param.block_public_policy
        restrict_public_buckets = param.restrict_public_buckets
      }
    }
  }

  step "pipeline" "create_public_s3_bucket" {
    pipeline = aws.pipeline.create_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  step "pipeline" "put_s3_bucket_public_access_block" {
    depends_on = [step.pipeline.create_public_s3_bucket]
    pipeline   = aws.pipeline.put_s3_bucket_public_access_block
    args       = step.transform.base_args_bucket_policy.output.base_args
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.put_s3_bucket_public_access_block]
    pipeline   = pipeline.correct_one_s3_bucket_if_publicly_accessible
    args = {
      title            = param.bucket
      bucket_name      = param.bucket
      conn             = param.conn
      region           = param.region
      default_action   = "block_public_access"
      enabled_actions  = ["block_public_access"]
    }
  }

  step "query" "verify_skip" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql = <<-EOQ
      select
        name,
        block_public_acls
      from
        aws_s3_bucket
      where
        name = '${param.bucket}'
        and block_public_acls = true
    EOQ
  }

  output "result" {
    description = "Result of skip action verification."
    value       = length(step.query.verify_skip.rows) == 1 ? "Bucket was enabled for blocking public access." : "Unexpected outcome."
  }

  output "results" {
    value = step.query.verify_skip
  }

  step "pipeline" "delete_s3_bucket" {
    # Don't run before we've had a chance to list buckets
    depends_on = [step.query.verify_skip]

    pipeline = aws.pipeline.delete_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  output "bucket" {
    description = "Bucket name used in the test."
    value       = param.bucket
  }
}
