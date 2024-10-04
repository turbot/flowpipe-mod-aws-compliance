locals {
  iam_access_analyzer_disabled_in_regions_query = <<-EOQ
    select
      concat(r.region, ' [', r.account_id, ']') as title,
      r.region,
      r._ctx ->> 'connection_name' as cred
    from
      aws_region as r
      left join aws_accessanalyzer_analyzer as aa on r.account_id = aa.account_id and r.region = aa.region
    where
      r.opt_in_status <> 'not-opted-in'
      and aa.arn is null;
  EOQ
}

variable "iam_access_analyzer_disabled_in_regions_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_access_analyzer_disabled_in_regions_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_access_analyzer_disabled_in_regions_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_access_analyzer_disabled_in_regions_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_access_analyzer"]
}

variable "iam_access_analyzer_disabled_in_regions_analyzer_name" {
  type        = string
  description = "The name of the IAM Access Analyzer."
  default     = "accessanalyzer"
}

trigger "query" "detect_and_correct_iam_access_analyzer_disabled_in_regions" {
  title         = "Detect and correct regions with IAM Access Analyzer disabled"
  description   = "Detects regions with IAM Access Analyzer disabled and then enable them."

  enabled  = var.iam_access_analyzer_disabled_in_regions_trigger_enabled
  schedule = var.iam_access_analyzer_disabled_in_regions_trigger_schedule
  database = var.database
  sql      = local.iam_access_analyzer_disabled_in_regions_query

  capture "insert" {
    pipeline = pipeline.correct_iam_access_analyzer_disabled_in_regions
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_access_analyzer_disabled_in_regions
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_access_analyzer_disabled_in_regions" {
  title         = "Detect and correct regions with IAM Access Analyzer disabled"
  description   = "Detects regions with IAM Access Analyzer disabled and then enable them."

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
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_access_analyzer_disabled_in_regions_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_access_analyzer_disabled_in_regions
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

pipeline "correct_iam_access_analyzer_disabled_in_regions" {
  title         = "Correct regions with IAM Access Analyzer disabled"
  description   = "Enable IAM Access Analyzer in regions with IAM Access Analyzer disabled."

  param "items" {
    type = list(object({
      title          = string
      analyzer_name  = string
      region         = string
      cred           = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "analyzer_name" {
    type        = string
    description = "analyzer_name"
    default     = var.iam_access_analyzer_disabled_in_regions_analyzer_name
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
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} region(s) with IAM Access Analyzer disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.region => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_access_analyzer_disabled_in_region
    args = {
      title              = each.value.title
      analyzer_name      = param.analyzer_name
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

pipeline "correct_one_iam_access_analyzer_disabled_in_region" {
  title         = "Correct region with IAM Access Analyzer disabled"
  description   = "Enable IAM Access Analyzer in a region with IAM Access Analyzer disabled."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "analyzer_name" {
    type        = string
    description = "The name of the IAM Access Analyzer."
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
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected region ${param.title} with IAM Access Analyzer disabled."
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
            text     = "Skipped region ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_access_analyzer" = {
          label        = "Enable IAM access analyzer"
          value        = "enable_access_analyzer"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.create_iam_access_analyzer
          pipeline_args = {
            analyzer_name = param.analyzer_name
            region        = param.region
            cred          = param.cred
          }
          success_msg = "Enabled IAM Access Analyzer in region ${param.title}."
          error_msg   = "Error enabling IAM Access Analyzer in region ${param.title}."
        }
      }
    }
  }
}


