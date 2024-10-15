locals {
  security_hub_disabled_in_regions_query = <<-EOQ
    select
      concat('[', r.account_id, '/', r.name, ']') as title,
      r.sp_connection_name as conn,
      r.name as region
    from
      aws_region as r
      left join aws_securityhub_hub as h on r.account_id = h.account_id and r.name = h.region
    where
      h.hub_arn is null
      and r.opt_in_status != 'not-opted-in'
      and r.region != any(array['af-south-1', 'eu-south-1', 'cn-north-1', 'cn-northwest-1', 'ap-northeast-3']);
  EOQ
}

variable "security_hub_disabled_in_regions_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/SecurityHub"
  }
}

variable "security_hub_disabled_in_regions_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/SecurityHub"
  }
}

variable "security_hub_disabled_in_regions_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/SecurityHub"
  }
}

variable "security_hub_disabled_in_regions_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_with_default_standards", "enable_without_default_standards"]

  tags = {
    folder = "Advanced/SecurityHub"
  }
}

trigger "query" "detect_and_correct_security_hub_disabled_in_regions" {
  title       = "Detect & correct Security Hub disabled in regions"
  description = "Detect regions with Security Hub disabled and then skip or enable Security Hub."
  tags        = local.security_hub_common_tags

  enabled  = var.security_hub_disabled_in_regions_trigger_enabled
  schedule = var.security_hub_disabled_in_regions_trigger_schedule
  database = var.database
  sql      = local.security_hub_disabled_in_regions_query

  capture "insert" {
    pipeline = pipeline.correct_security_hub_disabled_in_regions
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_security_hub_disabled_in_regions" {
  title       = "Detect & correct Security Hub disabled in regions"
  description = "Detect regions with Security Hub disabled and then skip or enable Security Hub."
  tags        = merge(local.security_hub_common_tags, { recommended = "true" })

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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.security_hub_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.security_hub_disabled_in_regions_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.security_hub_disabled_in_regions_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_security_hub_disabled_in_regions
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_security_hub_disabled_in_regions" {
  title       = "Correct regions with Security Hub disabled"
  description = "Enable Security Hub in regions with Security Hub disabled."
  tags          = merge(local.security_hub_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title  = string
      region = string
      conn   = string
    }))
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.security_hub_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.security_hub_disabled_in_regions_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} region(s) with Security Hub disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_region_with_security_hub_disabled
    args = {
      title              = each.value.title
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_region_with_security_hub_disabled" {
  title       = "Correct one region with Security Hub disabled"
  description = "Enable Security Hub in a single region with Security Hub disabled."
  tags          = merge(local.security_hub_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.security_hub_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.security_hub_disabled_in_regions_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected ${param.title} with Security Hub disabled."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_info
            text     = "Skipped ${param.title} with Security Hub disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_with_default_standards" = {
          label        = "Enable with Default Standards"
          value        = "enable_with_default_standards"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.enable_security_hub
          pipeline_args = {
            region                   = param.region
            enable_default_standards = true
            conn                     = param.conn
          }
          success_msg = "Enabled Security Hub with default standards in region ${param.title}."
          error_msg   = "Error enabling Security Hub with default standards in region ${param.title}."
        },
        "enable_without_default_standards" = {
          label        = "Enable without Default Standards"
          value        = "enable_without_default_standards"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.enable_security_hub
          pipeline_args = {
            region                   = param.region
            enable_default_standards = false
            conn                     = param.conn
          }
          success_msg = "Enabled Security Hub without default standards in region ${param.title}."
          error_msg   = "Error enabling Security Hub without default standards in region ${param.title}."
        }
      }
    }
  }
}
