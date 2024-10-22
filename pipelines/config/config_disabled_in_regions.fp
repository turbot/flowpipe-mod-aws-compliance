locals {
  config_disabled_in_regions_query = <<-EOQ
    with global_recorders as (
      select
        count(*) as global_config_recorders
      from
        aws_config_configuration_recorder
      where
        recording_group -> 'IncludeGlobalResourceTypes' = 'true'
        and recording_group -> 'AllSupported' = 'true'
        and status ->> 'Recording' = 'true'
        and status ->> 'LastStatus' = 'SUCCESS'
    )
    select
      concat('[', a.account_id, '/', a.name, ']') as title,
      a.sp_connection_name as conn,
      a.name as region
    from
      global_recorders as g,
      aws_region as a
      left join aws_config_configuration_recorder as r on r.account_id = a.account_id
      and r.region = a.name
    where
      a.opt_in_status != 'not-opted-in'
      and g.global_config_recorders >= 1
      and status is null;
  EOQ
}

variable "config_disabled_in_regions_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Config"
  }
}

variable "config_disabled_in_regions_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Config"
  }
}

trigger "query" "detect_and_correct_config_disabled_in_regions" {
  title       = "Detect & correct Config disabled in regions"
  description = "Detect Config disabled in regions."
  tags        = local.config_common_tags

  enabled  = var.config_disabled_in_regions_trigger_enabled
  schedule = var.config_disabled_in_regions_trigger_schedule
  database = var.database
  sql      = local.config_disabled_in_regions_query

  capture "insert" {
    pipeline = pipeline.correct_config_disabled_in_regions
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_config_disabled_in_regions" {
  title       = "Detect & correct Config disabled in regions"
  description = "Detect Config disabled in regions."

  tags = merge(local.config_common_tags, { recommended = "true" })

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
  }

  step "query" "detect" {
    database = param.database
    sql      = local.config_disabled_in_regions_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_config_disabled_in_regions
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_config_disabled_in_regions" {
  title       = "Correct Config disabled in regions"
  description = "Send notifications for regions with Config disabled."

  tags = merge(local.config_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title  = string
      region = string
      conn   = string
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
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} region(s) with Config disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected region ${each.value.title} with Config disabled."
  }
}
