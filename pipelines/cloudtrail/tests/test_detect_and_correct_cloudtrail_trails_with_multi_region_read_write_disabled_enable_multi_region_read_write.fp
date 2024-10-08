pipeline "test_test_detect_and_correct_cloudtrail_trails_with_multi_region_read_write_disabled_enable_multi_region_read_write" {
  title       = "Test detect & correct CloudTrail trails without multi-region read/write enabled"
  description = "Test enable mulit-region trail read/write in the account."

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
    default     = "test-fp-multi-region-trail"
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = "test-fp-multi-region-trail-bucket"
  }

  step "query" "verify_trails_with_multi_region_read_write_disabled" {
    database = var.database
    sql      = <<-EOQ
      with event_selectors_trail_details as (
        select distinct
          name,
          account_id
        from
          aws_cloudtrail_trail,
          jsonb_array_elements(event_selectors) as e
        where
          (is_logging and is_multi_region_trail and e ->> 'ReadWriteType' = 'All')
      ),
      advanced_event_selectors_trail_details as (
        select distinct
          name,
          account_id
        from
          aws_cloudtrail_trail,
          jsonb_array_elements_text(advanced_event_selectors) as a
        where
          (is_logging and is_multi_region_trail and advanced_event_selectors is not null and (not a like '%readOnly%'))
      )
      select
        concat(a.title, ' [', a.account_id, ']') as title,
        case
          when d.account_id is null
          and ad.account_id is null then 'disabled'
          else 'enabled'
        end as multi_region_read_weite_status,
        a.account_id,
        a._ctx ->> 'connection_name' as cred
      from
        aws_account as a
        left join event_selectors_trail_details as d on d.account_id = a.account_id
        left join advanced_event_selectors_trail_details as ad on ad.account_id = a.account_id;
    EOQ

    // Exit pipeline if multi-region trail read/write is enabled
    throw {
      if      = result.rows[0].multi_region_read_weite_status == "enabled"
      message = "The ClooudTrail multi-region trail in '${result.rows[0].title}' with read/write is enabled. Exiting the pipeline."
    }
  }


  step "pipeline" "run_detection" {
    depends_on = [step.query.verify_trails_with_multi_region_read_write_disabled]
    pipeline   = pipeline.correct_one_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      account_id      = step.query.verify_trails_with_multi_region_read_write_disabled.rows[0].account_id
      title           = step.query.verify_trails_with_multi_region_read_write_disabled.rows[0].title
      trail_name      = param.trail_name
      bucket_name     = param.bucket_name
      region          = param.region
      cred            = param.cred
      approvers       = []
      default_action  = "enable_multi_region_read_write"
      enabled_actions = ["enable_multi_region_read_write"]
    }
  }

  step "query" "enabled_multi_region_read_write_disabled" {
    depends_on = [step.query.verify_trails_with_multi_region_read_write_disabled, step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      with event_selectors_trail_details as (
        select distinct
          name,
          account_id
        from
          aws_cloudtrail_trail,
          jsonb_array_elements(event_selectors) as e
        where
          (is_logging and is_multi_region_trail and e ->> 'ReadWriteType' = 'All')
      ),
      advanced_event_selectors_trail_details as (
        select distinct
          name,
          account_id
        from
          aws_cloudtrail_trail,
          jsonb_array_elements_text(advanced_event_selectors) as a
        where
          (is_logging and is_multi_region_trail and advanced_event_selectors is not null and (not a like '%readOnly%'))
      )
      select
        concat(a.title, ' [', a.account_id, ']') as title,
        case
          when d.account_id is null
          and ad.account_id is null then 'disabled'
          else 'enabled'
        end as multi_region_read_weite_status,
        a.account_id,
        a._ctx ->> 'connection_name' as cred
      from
        aws_account as a
        left join event_selectors_trail_details as d on d.account_id = a.account_id
        left join advanced_event_selectors_trail_details as ad on ad.account_id = a.account_id;
    EOQ
  }


  step "pipeline" "delete_cloudtrail_trail" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_multi_region_read_write_disabled]

    pipeline = aws.pipeline.delete_cloudtrail_trail
    args = {
      cred   = param.cred
      name   = param.trail_name
      region = param.region
    }
  }

  // Cleanup all objects before deleting it.
  step "pipeline" "delete_s3_bucket_all_objects" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_multi_region_read_write_disabled]

    pipeline = aws.pipeline.delete_s3_bucket_all_objects
    args = {
      cred   = param.cred
      bucket = param.bucket_name
      region = param.region
    }
  }

  // Delete the bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.pipeline.run_detection, step.query.enabled_multi_region_read_write_disabled, step.pipeline.delete_s3_bucket_all_objects]

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
      "enabled_multi_region_read_write_disabled" = step.query.enabled_multi_region_read_write_disabled.rows[0].multi_region_read_weite_status == "enabled" ? "pass" : "fail"
      "verify_trails_with_multi_region_read_write_disabled" : length(step.query.verify_trails_with_multi_region_read_write_disabled.rows) > 0 ? "pass" : "fail"
      "delete_cloudtrail_trail"      = !is_error(step.pipeline.delete_cloudtrail_trail) ? "pass" : "fail"
      "delete_s3_bucket_all_objects" = !is_error(step.pipeline.delete_s3_bucket_all_objects) ? "pass" : "fail"
      "delete_s3_bucket"             = !is_error(step.pipeline.delete_s3_bucket) ? "pass" : "fail"
    }
  }
}
