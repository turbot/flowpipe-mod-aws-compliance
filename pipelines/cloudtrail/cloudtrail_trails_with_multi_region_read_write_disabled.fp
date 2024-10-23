locals {
  cloudtrail_trails_with_multi_region_read_write_disabled_query = <<-EOQ
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
    a.account_id,
    a.sp_connection_name as conn
  from
    aws_account as a
    left join event_selectors_trail_details as d on d.account_id = a.account_id
    left join advanced_event_selectors_trail_details as ad on ad.account_id = a.account_id
  where
    ad.account_id is null and d.account_id is null;
  EOQ
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_enabled_region" {
  type        = string
  description = "The AWS region where the trail and bucket will be created."
  default     = "us-east-1"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_trail_name" {
  type        = string
  description = "The name of the trail."
  default     = "test-fp-multi-region-trail"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_bucket_name" {
  type        = string
  description = "The name of the bucket."
  default     = "test-fp-multi-region-trail-bucket"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_multi_region_read_write_disabled" {
  title       = "Detect & correct CloudTrail trails with multi-region read/write disabled"
  description = "Detect CloudTrail trails with multi-region read/write disabled."

  tags = local.cloudtrail_common_tags

  enabled  = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled
  schedule = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_multi_region_read_write_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_multi_region_read_write_disabled" {
  title       = "Detect & correct CloudTrail trails with multi-region read/write disabled"
  description = "Detects CloudTrail trails with multi-region read/write disabled."

  tags = merge(local.cloudtrail_common_tags, { recommended = "true" })

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
    sql      = local.cloudtrail_trails_with_multi_region_read_write_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_cloudtrail_trail_with_multi_region_read_write_disabled" {
  title       = "Correct CloudTrail trails with multi-region read/write disabled"
  description = "Send notifications for CloudTrail trails with multi-region read/write disabled."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title      = string
      conn       = string
      account_id = string
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
    text     = "Detected ${length(param.items)} account(s) with multi-region read/write disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected account ${each.value.title} with multi-region read/write disabled."
  }
}
