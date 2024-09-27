locals {
  cloudtrail_trails_with_log_validation_disabled_query = <<-EOQ
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    _ctx ->> 'connection_name' as cred
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
}

variable "cloudtrail_trails_with_log_file_validation_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"
}

variable "cloudtrail_trails_with_log_file_validation_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "cloudtrail_trails_with_log_file_validation_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_log_file_validation"]
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & Correct CloudTrail Trails With Log File Validation Disabled"
  description   = "Detect CloudTrail trails with log file validation disabled and then skip or enable log file validation."
  //documentation = file("./cloudtrail/docs/cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = local.cloudtrail_common_tags

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

  capture "update" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & Correct CloudTrail Trails with Log File Validation Disabled"
  description   = "Detect CloudTrail trails with log file validation disabled and then skip or enable log file validation."
  //documentation = file("./cloudtrail/docs/cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = local.cloudtrail_common_tags

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
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
  title         = "Correct CloudTrail Trails Log File Validation Disabled"
  description   = "Enable log file validation for CloudTrail trails with log file validation disabled."
  //documentation = file("./cloudtrail/docs/cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = local.cloudtrail_common_tags

  param "items" {
    type = list(object({
      title  = string
      name   = string
      region = string
      cred   = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
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
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trail(s) with log file validation disabled."
  }

  step "pipeline" "correct_cloudtrail_trails_with_log_file_validation_disabled" {
    for_each        = { for row in param.items: row.name => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_log_file_validation_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_log_file_validation_disabled" {
  title         = "Correct CloudTrail Trail Log File Validation Disabled"
  description   = "Enable log file validation for a CloudTrail trail with log file validation disabled."
  //documentation = file("./cloudtrail/docs/cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = local.cloudtrail_common_tags

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

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
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
            cred                       = param.cred
          }
          success_msg = "Enabled log file validation for CloudTrail trail ${param.title}."
          error_msg   = "Error enabling log file validation for CloudTrail trail ${param.title}."
        }
      }
    }
  }
}
