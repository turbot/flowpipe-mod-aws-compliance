# TODO: Should this pipeline create trails, or just update existing ones?
locals {
  cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_query = <<-EOQ
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

variable "cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled" {
  title       = "Detect & correct CloudTrail trails with S3 object level logging for write events disabled"
  description = "Detect CloudTrail trails with S3 object level logging for write events disabled"

  tags = local.cloudtrail_common_tags

  enabled  = var.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_trigger_enabled
  schedule = var.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled" {
  title       = "Detect & correct CloudTrail trails with S3 object level logging for write events disabled"
  description = "Detect CloudTrail trails with S3 object level logging for write events disabled"

  tags = local.cloudtrail_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled" {
  title       = "Correct CloudTrail trails with S3 object write events audit disabled"
  description = "Send notifications for CloudTrail trails with S3 object write events audit disabled."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                 = string
      bucket_selector_count = number
      conn                  = string
      account_id            = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} account(s) trail with S3 object write events audit disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected account ${each.value.title} trail with S3 object level logging for write events disabled."
  }
}
