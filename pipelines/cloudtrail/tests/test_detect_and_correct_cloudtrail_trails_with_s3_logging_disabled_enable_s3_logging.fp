pipeline "test_detect_and_correct_cloudtrail_trails_with_s3_logging_disabled_enable_s3_logging" {
  title       = "Test detect & correct CloudTrail trails with S3 logging disabled"
  description = "Test detect CloudTrail trails with S3 logging disabled and then skip or enable S3 logging."

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
    description = "The AWS region where the resource will be created."
    default     = "us-east-1"
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = "test-fp-s3-logging-trail"
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = "test-fp-s3-logging-trail"
  }

  step "query" "get_account_id" {
    database = var.database
    sql      = <<-EOQ
      select
        account_id
      from
        aws_account;
    EOQ
  }

  step "pipeline" "create_s3_bucket_for_trail_logging" {
    depends_on = [step.query.get_account_id]
    pipeline   = aws.pipeline.create_s3_bucket
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_logging]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      region = "us-east-1"
      cred   = param.cred
      bucket = param.bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}/AWSLogs/${step.query.get_account_id.rows[0].account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "create_trail_with_s3_logging_disabled" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_logging, step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      region                        = param.region
      cred                          = param.cred
      name                          = param.trail_name
      bucket_name                   = param.bucket_name
      is_multi_region_trail         = false
      include_global_service_events = false
      enable_log_file_validation    = false
    }
  }

  step "query" "verify_trail_with_s3_logging_disabled" {
    depends_on = [step.pipeline.create_trail_with_s3_logging_disabled]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(t.name, ' [', t.region, '/', t.account_id, ']') as title,
        t.arn as resource,
        t.name,
        t.region,
        t.account_id,
        t._ctx ->> 'connection_name' as cred
      from
        aws_cloudtrail_trail t
        inner join aws_s3_bucket b on t.s3_bucket_name = b.name
      where
        t.name = '${param.trail_name}'
        and t.region = t.home_region
        and b.logging is null;
    EOQ

  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_trail_with_s3_logging_disabled, step.query.verify_trail_with_s3_logging_disabled]
    pipeline   = pipeline.correct_one_cloudtrail_trail_with_s3_logging_disabled
    args = {
      account_id      = step.query.verify_trail_with_s3_logging_disabled.rows[0].account_id
      title           = step.query.verify_trail_with_s3_logging_disabled.rows[0].title
      name            = param.trail_name
      bucket_name     = param.bucket_name
      region          = param.region
      cred            = param.cred
      approvers       = []
      default_action  = "enable_s3_logging"
      enabled_actions = ["enable_s3_logging"]
    }
  }

  step "query" "enabled_trail_with_s3_logging_disabled_after_detection" {
    depends_on = [step.pipeline.create_trail_with_s3_logging_disabled, step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(t.name, ' [', t.region, '/', t.account_id, ']') as title,
        t.arn as resource,
        t.name,
        t.region,
        t.account_id,
        t._ctx ->> 'connection_name' as cred
      from
        aws_cloudtrail_trail t
        inner join aws_s3_bucket b on t.s3_bucket_name = b.name
      where
        t.name = '${param.trail_name}'
        and t.region = t.home_region
        and b.logging is not null;
    EOQ
  }

  step "pipeline" "delete_cloudtrail_trail" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_trail_with_s3_logging_disabled_after_detection]

    pipeline = aws.pipeline.delete_cloudtrail_trail
    args = {
      cred   = param.cred
      name   = param.trail_name
      region = param.region
    }
  }

  // Cleanup all objects before deleting it.
  step "pipeline" "delete_s3_bucket_all_objects" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_trail_with_s3_logging_disabled_after_detection, steps.pipeline.delete_cloudtrail_trail]

    pipeline = aws.pipeline.delete_s3_bucket_all_objects
    args = {
      cred   = param.cred
      bucket = param.bucket_name
      region = param.region
    }
  }

  // Delete the bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_trail_with_s3_logging_disabled_after_detection, step.pipeline.delete_s3_bucket_all_objects]

    pipeline = aws.pipeline.delete_s3_bucket
    args = {
      cred   = param.cred
      bucket = param.bucket_name
      region = param.region
    }
  }

  output "result_multi_region_read_write_disabled" {
    description = "Test result for each step"
    value = {
      "get_account_id"                        = length(step.query.get_account_id.rows) > 0 ? "pass" : "fail"
      "create_s3_bucket_for_trail_logging"    = !is_error(step.pipeline.create_s3_bucket_for_trail_logging) ? "pass" : "fail"
      "put_s3_bucket_policy"                  = !is_error(step.pipeline.put_s3_bucket_policy) ? "pass" : "fail"
      "delete_cloudtrail_trail"               = !is_error(step.pipeline.delete_cloudtrail_trail) ? "pass" : "fail"
      "delete_s3_bucket_all_objects"          = !is_error(step.pipeline.delete_s3_bucket_all_objects) ? "pass" : "fail"
      "delete_s3_bucket"                      = !is_error(step.pipeline.delete_s3_bucket) ? "pass" : "fail"
      "create_trail_with_s3_logging_disabled" = !is_error(step.pipeline.create_trail_with_s3_logging_disabled) ? "pass" : "fail"
      "verify_trail_with_s3_logging_disabled" : length(step.query.verify_trail_with_s3_logging_disabled.rows) > 0 ? "pass" : "fail"
      "enabled_trail_with_s3_logging_disabled_after_detection" : length(step.query.enabled_trail_with_s3_logging_disabled_after_detection.rows) > 0 ? "pass" : "fail"
    }
  }
}
