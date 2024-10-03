pipeline "test_cloudtrail_trail_with_s3_object_level_logging_for_read_events_disabled" {
  title       = "Test Correct One CloudTrail Trail with S3 Object Level Logging for Read Events Disabled"
  description = "Tests the correction of a CloudTrail trail with S3 object level logging for read events disabled."

  param "cred" {
    type        = string
    description = "The AWS credential to use."
    default     = "default"
  }

  param "region" {
    type        = string
    description = "The AWS region."
    default     = "us-east-1"
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = "test-cloudtrail-${uuid()}"
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket for CloudTrail logs."
    default     = "test-cloudtrail-s3-bucket-${uuid()}"
  }

  # Step to get AWS Account ID
  step "query" "get_account_id" {
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_account
      limit 1;
    EOQ
  }

  # Step to create an S3 bucket for CloudTrail logs
  step "pipeline" "create_s3_bucket" {
    depends_on = [step.query.get_account_id]
    pipeline   = aws.pipeline.create_s3_bucket
    args = {
      bucket = param.s3_bucket_name
      cred   = param.cred
      region = param.region
    }
  }

  # Step to set S3 bucket policy for CloudTrail
  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      bucket = param.s3_bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}/AWSLogs/${step.query.get_account_id.rows[0].account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
      cred   = param.cred
      region = param.region
    }
  }

  # Step to create a CloudTrail trail without S3 object-level logging for read events
  step "pipeline" "create_cloudtrail_trail" {
    depends_on = [step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      name                          = param.trail_name
      region                        = param.region
      cred                          = param.cred
      bucket_name                   = param.s3_bucket_name
      is_multi_region_trail         = true
      include_global_service_events = true
      enable_log_file_validation    = true
    }
  }

  # Step to set event selectors for the CloudTrail trail
  step "pipeline" "set_event_selectors" {
    depends_on = [step.pipeline.create_cloudtrail_trail]
    pipeline   = aws.pipeline.put_cloudtrail_trail_event_selector
    args = {
      region          = param.region
      trail_name      = param.trail_name
      event_selectors = "[{ \"ReadWriteType\": \"ReadOnly\", \"IncludeManagementEvents\":true, \"DataResources\": [{ \"Type\": \"AWS::S3::Object\", \"Values\": [\"arn:aws:s3:::${param.s3_bucket_name}/\"] }] }]"
      cred            = param.cred
    }
  }

  # Verify that the trail now has S3 object-level logging for read events enabled
  step "query" "verify_trail_s3_object_read_events_enabled" {
    depends_on = [step.pipeline.set_event_selectors]
    database   = var.database
    sql        = <<-EOQ
      select
        name,
        event_selectors
      from
        aws_cloudtrail_trail
      where
        name = '${param.trail_name}'
        and exists (
          select 1
          from
            jsonb_array_elements(event_selectors) as event_selector,
            jsonb_array_elements(event_selector -> 'DataResources') as data_resource
          where
            data_resource ->> 'Type' = 'AWS::S3::Object'
            and event_selector ->> 'ReadWriteType' in ('ReadOnly', 'All')
        );
    EOQ
  }

  output "result" {
    description = "Result of the test."
    value       = length(step.query.verify_trail_s3_object_read_events_enabled.rows) == 1 ? "S3 object-level logging for read events is enabled." : "S3 object-level logging for read events is not enabled."
  }

  # Cleanup steps
  # Delete the CloudTrail trail
  step "container" "delete_cloudtrail_trail" {
    depends_on = [step.query.verify_trail_s3_object_read_events_enabled]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "cloudtrail", "delete-trail",
      "--name", param.trail_name,
      "--region", param.region
    ]
    env = credential.aws[param.cred].env
  }


  # Step to empty the S3 bucket before deletion
  step "container" "empty_s3_bucket" {
    depends_on = [step.container.delete_cloudtrail_trail]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3", "rm", "s3://${param.s3_bucket_name}", "--recursive",
      "--region", param.region
    ]
    env = credential.aws[param.cred].env
  }

  # Delete the S3 bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.container.empty_s3_bucket]
    pipeline   = aws.pipeline.delete_s3_bucket
    args = {
      bucket = param.s3_bucket_name
      cred   = param.cred
      region = param.region
    }
  }
}