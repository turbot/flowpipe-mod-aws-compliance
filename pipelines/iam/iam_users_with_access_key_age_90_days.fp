locals {
  iam_users_with_access_key_age_90_days_query = <<-EOQ
    select
      concat(access_key_id, ' [', account_id, ']') as title,
      access_key_id,
      user_name,
      account_id,
      sp_connection_name as conn,
      create_date as access_key_create_date,
      (extract(day from now() - create_date))::text as access_key_create_day
    from
      aws_iam_access_key
    where
      create_date <= (current_date - interval '90' day);
  EOQ

  iam_users_with_access_key_age_90_days_default_action_enum  = ["notify", "skip", "deactivate_access_key"]
  iam_users_with_access_key_age_90_days_enabled_actions_enum = ["skip", "deactivate_access_key"]
}

variable "iam_users_with_access_key_age_90_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_age_90_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_age_90_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "deactivate_access_key"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_age_90_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "deactivate_access_key"]
  enum        = ["skip", "deactivate_access_key"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_access_key_age_90_days" {
  title       = "Detect & correct IAM users with unused access key from 90 days or more"
  description = "Detects IAM users access key that have been unused for 90 days or more and deactivates them."
  tags        = local.iam_common_tags

  enabled  = var.iam_users_with_access_key_age_90_days_trigger_enabled
  schedule = var.iam_users_with_access_key_age_90_days_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_access_key_age_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_access_key_age_90_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_access_key_age_90_days" {
  title       = "Detect & correct IAM users with unused access key from 90 days or more"
  description = "Detects IAM users access key that have been unused for 90 days or more and deactivates them."

  tags = merge(local.iam_common_tags, { recommended = "true" })

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
    default     = var.iam_users_with_access_key_age_90_days_default_action
    enum        = local.iam_users_with_access_key_age_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_age_90_days_enabled_actions
    enum        = local.iam_users_with_access_key_age_90_days_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_access_key_age_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_access_key_age_90_days
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

pipeline "correct_iam_users_with_access_key_age_90_days" {
  title       = "Correct IAM users with unused access key from 90 days or more"
  description = "Runs corrective action to deactivate IAM users access key that have been unused for 90 days or more."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                  = string
      user_name              = string
      account_id             = string
      access_key_create_date = string
      access_key_create_day  = string
      access_key_id          = string
      conn                   = string
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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_users_with_access_key_age_90_days_default_action
    enum        = local.iam_users_with_access_key_age_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_age_90_days_enabled_actions
    enum        = local.iam_users_with_access_key_age_90_days_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user(s) access key aged 90 days or more."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_access_key_age_90_days
    args = {
      title                  = each.value.title
      user_name              = each.value.user_name
      access_key_id          = each.value.access_key_id
      access_key_create_date = each.value.access_key_create_date
      access_key_create_day  = each.value.access_key_create_day
      conn                   = connection.aws[each.value.conn]
      notifier               = param.notifier
      notification_level     = param.notification_level
      approvers              = param.approvers
      default_action         = param.default_action
      enabled_actions        = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_access_key_age_90_days" {
  title       = "Correct one IAM user with unused access key from 90 days or more"
  description = "Runs corrective action to deactivate a IAM user access key that have been unused for 90 days or more."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
  }

  param "access_key_create_date" {
    type        = string
    description = "The IAM user access key creation date."
  }

  param "access_key_create_day" {
    type        = string
    description = "The number of days since the IAM user's access key was created."
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
    default     = var.iam_users_with_access_key_age_90_days_default_action
    enum        = local.iam_users_with_access_key_age_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_age_90_days_enabled_actions
    enum        = local.iam_users_with_access_key_age_90_days_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.user_name} with access key ${param.title} created on ${param.access_key_create_date} (${param.access_key_create_day} days old)."
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
            text     = "Skipped IAM user ${param.user_name} access key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "deactivate_access_key" = {
          label        = "Deactivate access key"
          value        = "deactivate_access_key"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_user_access_key
          pipeline_args = {
            user_name     = param.user_name
            access_key_id = param.access_key_id
            conn          = param.conn
          }
          success_msg = "Deactivated IAM user ${param.user_name} with access key ${param.title} created on ${param.access_key_create_date} (${param.access_key_create_day} days old)."
          error_msg   = "Error deactivating IAM user ${param.user_name} with access key ${param.title} created on ${param.access_key_create_date} (${param.access_key_create_day} days old)."
        }
      }
    }
  }
}
