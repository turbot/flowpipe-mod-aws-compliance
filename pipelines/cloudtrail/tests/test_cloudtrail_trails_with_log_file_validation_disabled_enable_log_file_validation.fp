pipeline "test_cloudtrail_trails_with_log_file_validation_disabled_enable_log_file_validation" {
  title       = "Test detect and correct cloudtrail trails with log file validation disabled"
  description = "Test detect CloudTrail trails with log file validation disabled."

  tags = {
    type = "test"
  }

  param "conn" {
    type        = string
    description = "The AWS connection to use."
    default     = connection.aws.default
  }

  param "region" {
    type        = string
    description = "The AWS region where the resource will be created."
    default     = "us-east-1"
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = "test-fp-log-file-validation-disabled-trail"
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = "flowpipe-test-log-file-validation-disabled-bucket"
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

  step "pipeline" "create_s3_bucket_for_trail_disable_file_validation" {
    depends_on = [step.query.get_account_id]
    pipeline   = aws.pipeline.create_s3_bucket
    args = {
      region = param.region
      conn   = param.conn
      bucket = param.bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_disable_file_validation]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      region = param.region
      conn   = param.conn
      bucket = param.bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}/AWSLogs/${step.query.get_account_id.rows[0].account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "create_trail_with_log_file_validation_disabled" {
    depends_on = [step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      region                        = param.region
      conn                          = param.conn
      name                          = param.trail_name
      bucket_name                   = param.bucket_name
      is_multi_region_trail         = false
      include_global_service_events = false
      enable_log_file_validation    = false
    }
  }

  step "query" "verify_trail_log_file_validation_is_disabled" {
    depends_on = [step.pipeline.create_trail_with_log_file_validation_disabled]
    database   = var.database
    sql        = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      name,
      region
    from
      aws_cloudtrail_trail
    where
      name = '${param.trail_name}'
      and not log_file_validation_enabled
      and region = home_region;
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.verify_trail_log_file_validation_is_disabled]
    pipeline   = pipeline.correct_one_cloudtrail_trail_log_file_validation_disabled
    args = {
      conn            = param.conn
      title           = step.query.verify_trail_log_file_validation_is_disabled.rows[0].title
      name            = param.trail_name
      region          = param.region
      approvers       = []
      default_action  = "enable_log_file_validation"
      enabled_actions = ["enable_log_file_validation"]
    }
  }

  step "query" "verify_trail_log_file_validation_is_enabled" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
    select
      name,
      region
    from
      aws_cloudtrail_trail
    where
      name = '${param.trail_name}'
      and log_file_validation_enabled
      and region = home_region;
    EOQ
  }

  step "pipeline" "delete_cloudtrail_trail" {
    depends_on = [step.query.verify_trail_log_file_validation_is_enabled]

    pipeline = aws.pipeline.delete_cloudtrail_trail
    args = {
      conn   = param.conn
      name   = param.trail_name
      region = param.region
    }
  }

  // Cleanup all objects before deleting it.
  step "pipeline" "delete_s3_bucket_all_objects" {
    depends_on = [step.pipeline.delete_cloudtrail_trail]

    pipeline = aws.pipeline.delete_s3_bucket_all_objects
    args = {
      conn   = param.conn
      bucket = param.bucket_name
      region = param.region
    }
  }

  // Delete the bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.pipeline.delete_s3_bucket_all_objects]

    pipeline = aws.pipeline.delete_s3_bucket
    args = {
      conn   = param.conn
      bucket = param.bucket_name
      region = param.region
    }
  }

  output "result_trail_with_log_file_validation_enabled" {
    description = "Test result for each step"
    value = {
      "get_account_id"                                     = length(step.query.get_account_id) > 0 ? "pass" : "fail"
      "create_s3_bucket_for_trail_disable_file_validation" = !is_error(step.pipeline.create_s3_bucket_for_trail_disable_file_validation) ? "pass" : "fail"
      "put_s3_bucket_policy"                               = !is_error(step.pipeline.put_s3_bucket_policy) ? "pass" : "fail"
      "create_trail_with_log_file_validation_disabled"     = !is_error(step.pipeline.create_trail_with_log_file_validation_disabled) ? "pass" : "fail"
      "verify_trail_log_file_validation_is_disabled"       = length(step.query.verify_trail_log_file_validation_is_disabled) > 0 ? "pass" : "fail"
      "verify_trail_log_file_validation_is_enabled"        = length(step.query.verify_trail_log_file_validation_is_enabled) > 0 ? "pass" : "fail"
      "delete_cloudtrail_trail"                            = !is_error(step.pipeline.delete_cloudtrail_trail) ? "pass" : "fail"
      "delete_s3_bucket_all_objects"                       = !is_error(step.pipeline.delete_s3_bucket_all_objects) ? "pass" : "fail"
      "delete_s3_bucket"                                   = !is_error(step.pipeline.delete_s3_bucket) ? "pass" : "fail"
    }
  }
}
