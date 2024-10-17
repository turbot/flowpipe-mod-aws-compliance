locals {
  cloudtrail_trails_with_log_validation_disabled_query = <<-EOQ
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    sp_connection_name as conn
  from
    aws_cloudtrail_trail
  where
    not log_file_validation_enabled
    and region = home_region;
  EOQ
}

variable "cloudtrail_trails_with_log_file_validation_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_log_file_validation_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_log_file_validation_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_log_file_validation_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_log_file_validation"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title       = "Detect & correct CloudTrail trails with log file validation disabled"
  description = "Detect CloudTrail trails with log file validation disabled and then enable log file validation."

  tags = local.cloudtrail_common_tags

  database = var.database
  enabled  = var.cloudtrail_trails_with_log_file_validation_disabled_trigger_enabled
  schedule = var.cloudtrail_trails_with_log_file_validation_disabled_trigger_schedule
  sql      = local.cloudtrail_trails_with_log_validation_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title       = "Detect & correct CloudTrail trails with log file validation disabled"
  description = "Detect CloudTrail trails with log file validation disabled and then enable log file validation."

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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_log_validation_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
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

pipeline "correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title       = "Correct CloudTrail trails with log file validation disabled"
  description = "Enable log file validation for CloudTrail trails with log file validation disabled."
  tags        = merge(local.cloudtrail_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title  = string
      name   = string
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected CloudTrail trail(s) ${length(param.items)} with log file validation disabled."
  }

  step "pipeline" "correct_cloudtrail_trails_with_log_file_validation_disabled" {
    for_each        = { for row in param.items : row.name => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_log_file_validation_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
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

pipeline "correct_one_cloudtrail_trail_log_file_validation_disabled" {
  title       = "Correct one CloudTrail trail with log file validation disabled"
  description = "Enable log file validation for a CloudTrail trail."
  tags        = merge(local.cloudtrail_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the CloudTrail trail."
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
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_log_file_validation_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail with log file validation disabled ${param.title}."
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
            send     = param.notification_level == local.level_verbose
            text     = "Skipped CloudTrail trail ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_log_file_validation" = {
          label        = "Enable log file validation"
          value        = "enable_log_file_validation"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.update_cloudtrail_trail
          pipeline_args = {
            trail_name                 = param.name
            enable_log_file_validation = true
            region                     = param.region
            conn                       = param.conn
          }
          success_msg = "Enabled log file validation for CloudTrail trail ${param.title}."
          error_msg   = "Error enabling log file validation for CloudTrail trail ${param.title}."
        }
      }
    }
  }
}
