pipeline "test_cloudtrail_trail_with_s3_object_level_logging_for_write_events_disabled" {
  title       = "Test Correct One CloudTrail Trail with S3 Object Level Logging for Write Events Disabled"
  description = "Tests the correction of a CloudTrail trail with S3 object level logging for write events disabled."

  param "conn" {
    type        = connection.aws
    description = "The AWS connection to use."
    default     = connection.aws.default
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
  step "query" "cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled" {
    database = var.database
    sql      = <<-EOQ
      with s3_selectors as
    (
      select
        t.name as trail_name,
        t.is_multi_region_trail,
        bucket_selector,
        t.region,
        t.account_id,
        t.sp_connection_name
      from
        aws_cloudtrail_trail as t,
        jsonb_array_elements(t.event_selectors) as event_selector,
        jsonb_array_elements(event_selector -> 'DataResources') as data_resource,
        jsonb_array_elements_text(data_resource -> 'Values') as bucket_selector
      where
        is_multi_region_trail
        and t.name = '${param.trail_name}'
        and data_resource ->> 'Type' = 'AWS::S3::Object'
        and event_selector ->> 'ReadWriteType' in
        (
          'WriteOnly',
          'All'
        )
    )
    select
      concat(a.title, ' [', '/', t.account_id, ']') as title,
      count(t.trail_name) as bucket_selector_count,
      a.account_id,
      a.sp_connection_name as conn
    from
      aws_account as a
      left join s3_selectors as t on a.account_id = t.account_id
    group by
      t.trail_name, t.region, a.account_id, t.account_id, a.sp_connection_name, a.title
    having
      count(t.trail_name) = 0;
    EOQ
  }

  step "pipeline" "run_detection" {
    pipeline = pipeline.correct_one_cloudtrail_trail_with_s3_object_level_logging_for_write_events_disabled
    args = {
      bucket_selector_count = step.query.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled.rows[0].bucket_selector_count
      title           = step.query.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled.rows[0].title
      s3_bucket_name  = param.s3_bucket_name
      trail_name      = param.trail_name
      account_id      = step.query.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled.rows[0].account_id
      conn            = step.query.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled.rows[0].conn
      approvers       = []
      default_action  = "enable_s3_object_level_logging_for_write_events"
      enabled_actions = ["enable_s3_object_level_logging_for_write_events"]
      home_region     = param.region
    }
  }

  # Verify that the trail now has S3 object-level logging for write events enabled
  step "query" "verify_trail_s3_object_write_events_enabled" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      with s3_selectors as
    (
      select
        t.name as trail_name,
        t.is_multi_region_trail,
        bucket_selector,
        t.region,
        t.account_id,
        t.sp_connection_name
      from
        aws_cloudtrail_trail as t,
        jsonb_array_elements(t.event_selectors) as event_selector,
        jsonb_array_elements(event_selector -> 'DataResources') as data_resource,
        jsonb_array_elements_text(data_resource -> 'Values') as bucket_selector
      where
        is_multi_region_trail
        and t.name = '${param.trail_name}'
        and data_resource ->> 'Type' = 'AWS::S3::Object'
        and event_selector ->> 'ReadWriteType' in
        (
          'WriteOnly',
          'All'
        )
    )
    select
      concat(a.title, ' [', '/', t.account_id, ']') as title,
      count(t.trail_name) as bucket_selector_count,
      a.account_id,
      a.sp_connection_name as conn
    from
      aws_account as a
      left join s3_selectors as t on a.account_id = t.account_id
    group by
      t.trail_name, t.region, a.account_id, t.account_id, a.sp_connection_name, a.title
    having
      count(t.trail_name) > 0;
    EOQ
  }

  output "result" {
    description = "Result of the test."
    value       = length(step.query.verify_trail_s3_object_write_events_enabled.rows) == 1 ? "S3 object-level logging for write events is enabled." : "S3 object-level logging for write events is not enabled."
  }

  # Cleanup steps
  # Delete the CloudTrail trail
  step "container" "delete_cloudtrail_trail" {
    depends_on = [step.query.verify_trail_s3_object_write_events_enabled]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "cloudtrail", "delete-trail",
      "--name", param.trail_name,
      "--region", param.region
    ]
    env = connection.aws[param.conn].env
  }

  # Step to empty the S3 bucket before deletion
  step "container" "empty_s3_bucket" {
    depends_on = [step.container.delete_cloudtrail_trail]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3", "rm", "s3://${param.s3_bucket_name}", "--recursive",
      "--region", param.region
    ]
    env = connection.aws[param.conn].env
  }

  # Delete the S3 bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.container.empty_s3_bucket]
    pipeline   = aws.pipeline.delete_s3_bucket
    args = {
      bucket = param.s3_bucket_name
      conn   = param.conn
      region = param.region
    }
  }
}
