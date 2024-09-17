locals {
  cloudtrail_trail_with_log_validation_disabled_query = <<-EOQ
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

variable "cloudtrail_trail_validation_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trail_validation_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_trail_validation_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "enable_validation"
}

variable "cloudtrail_trail_validation_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_validation"]
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & Correct CloudTrail trails With Log File Validation Disabled"
  // TODO: Improve the last part of this description
  description   = "Detect CloudTrail trails with log file validation disabled and then enable log file validation for these trails."
  //documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled_trigger.md")
  // TODO: What tags to add?
  tags          = local.cloudtrail_common_tags

  database = var.database
  enabled  = var.cloudtrail_trail_validation_enabled_trigger_enabled
  schedule = var.cloudtrail_trail_validation_enabled_trigger_schedule
  sql      = local.cloudtrail_trail_with_log_validation_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
    args = {
      trails = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & Correct CloudTrail Trails With Log File Validation Disabled"
  // TODO: Improve the last part of this description
  description   = "Detect CloudTrail trails with log file validation disabled and then enable log file validation for these trails."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled.md")
  // TODO: What tags to add?
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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_with_log_validation_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
    args = {
      trails             = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Correct CloudTrail Trails With Log File Validation Disabled"
  description   = "Enable log file validation for CloudTrail trails with log file validation disabled."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "trails" {
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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.trails)} CloudTrail trails with log file validation disabled."
  }

  step "transform" "trail_names" {
    value = { for row in param.trails: row.name => row }
  }

  step "pipeline" "correct_cloudtrail_trails_with_log_file_validation_disabled" {
    for_each        = step.transform.trail_names.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_cloudtrail_trail_with_log_file_validation_disabled
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

pipeline "correct_cloudtrail_trail_with_log_file_validation_disabled" {
  title         = "Correct CloudTrail Trail With Log File Validation Enabled"
  description   = "Enable log file validation for a CloudTrail trail with log file validation disabled."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trail_with_log_file_validation_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
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
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped CloudTrail trail ${param.title} with log file validation disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_validation" = {
          label        = "Enable log file validation"
          value        = "enable_validation"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_enable_cloudtrail_validation
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
