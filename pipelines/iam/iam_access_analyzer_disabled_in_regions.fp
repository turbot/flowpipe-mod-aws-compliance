locals {
  iam_access_analyzer_disabled_in_regions_query = <<-EOQ
    select
      concat(r.region, ' [', r.account_id, ']') as title,
      r.region,
      r.sp_connection_name as conn
    from
      aws_region as r
      left join aws_accessanalyzer_analyzer as aa on r.account_id = aa.account_id and r.region = aa.region
    where
      r.opt_in_status <> 'not-opted-in'
      and aa.arn is null;
  EOQ

  iam_access_analyzer_disabled_in_regions_default_action_enum  = ["notify", "skip", "enable_access_analyzer"]
  iam_access_analyzer_disabled_in_regions_enabled_actions_enum = ["skip", "enable_access_analyzer"]
}

variable "iam_access_analyzer_disabled_in_regions_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_access_analyzer_disabled_in_regions_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_access_analyzer_disabled_in_regions_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "enable_access_analyzer"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_access_analyzer_disabled_in_regions_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_access_analyzer"]
  enum        = ["skip", "enable_access_analyzer"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_access_analyzer_disabled_in_regions_analyzer_name" {
  type        = string
  description = "The name of the IAM Access Analyzer."
  default     = "accessanalyzer"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_access_analyzer_disabled_in_regions" {
  title       = "Detect & correct regions with IAM Access Analyzer disabled"
  description = "Detects regions with IAM Access Analyzer disabled and then enable them."
  tags        = local.iam_common_tags

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
}

pipeline "detect_and_correct_iam_access_analyzer_disabled_in_regions" {
  title       = "Detect & correct regions with IAM Access Analyzer disabled"
  description = "Detects regions with IAM Access Analyzer disabled and then enable them."
  tags        = local.iam_common_tags

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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
    enum        = local.iam_access_analyzer_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
    enum        = local.iam_access_analyzer_disabled_in_regions_enabled_actions_enum
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
  title       = "Correct regions with IAM Access Analyzer disabled"
  description = "Enable IAM Access Analyzer in regions with IAM Access Analyzer disabled."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

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

  param "analyzer_name" {
    type        = string
    description = "The name of the IAM Access Analyzer."
    default     = var.iam_access_analyzer_disabled_in_regions_analyzer_name
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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
    enum        = local.iam_access_analyzer_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
    enum        = local.iam_access_analyzer_disabled_in_regions_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
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
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_access_analyzer_disabled_in_region" {
  title       = "Correct one region with IAM Access Analyzer disabled"
  description = "Enable IAM Access Analyzer in a region with IAM Access Analyzer disabled."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_access_analyzer_disabled_in_regions_default_action
    enum        = local.iam_access_analyzer_disabled_in_regions_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_access_analyzer_disabled_in_regions_enabled_actions
    enum        = local.iam_access_analyzer_disabled_in_regions_enabled_actions_enum
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
            conn          = param.conn
          }
          success_msg = "Enabled IAM Access Analyzer in region ${param.title}."
          error_msg   = "Error enabling IAM Access Analyzer in region ${param.title}."
        }
      }
    }
  }
}


