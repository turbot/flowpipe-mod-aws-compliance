locals {
  iam_users_with_unused_login_profile_90_days_query = <<-EOQ
    select
      concat(u.name, ' [', u.account_id, ']') as title,
      u.name as user_name,
      coalesce(r.password_last_used::text, 'Never Used') as password_last_used,
      r.password_last_changed,
      coalesce(((extract(day from now() - r.password_last_used))::text), 'Never Used') as password_last_used_in_days,
      (extract(day from now() - r.password_last_changed))::text as password_last_changed_in_days,
      u.account_id,
      u.sp_connection_name as conn
    from
      aws_iam_user as u
      left join aws_iam_credential_report as r on r.user_name = u.name and u.account_id = r.account_id
    where
      (r.password_enabled and r.password_last_used is null and r.password_last_changed < (current_date - interval '90' day)
      or r.password_enabled and r.password_last_used < (current_date - interval '90' day));
  EOQ

  iam_users_with_unused_login_profile_90_days_default_action_enum  = ["notify", "skip", "delete_user_login_profile_unused_90_days"]
  iam_users_with_unused_login_profile_90_days_enabled_actions_enum = ["skip", "delete_user_login_profile_unused_90_days"]
}

variable "iam_users_with_unused_login_profile_90_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_login_profile_90_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_login_profile_90_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "delete_user_login_profile_unused_90_days"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_login_profile_90_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_user_login_profile_unused_90_days"]
  enum        = ["skip", "delete_user_login_profile_unused_90_days"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_unused_login_profile_90_days" {
  title       = "Detect & correct IAM users with unused login profile from 90 days or more"
  description = "Detects IAM users with login profile that have been unused for 90 days or more and delete them."
  tags        = local.iam_common_tags

  enabled  = var.iam_users_with_unused_login_profile_90_days_trigger_enabled
  schedule = var.iam_users_with_unused_login_profile_90_days_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_unused_login_profile_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_unused_login_profile_90_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_unused_login_profile_90_days" {
  title       = "Detect & correct IAM users with unused login profile from 90 days or more"
  description = "Detects IAM users with login profile that have been unused for 90 days or more and delete them."
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
    default     = var.iam_users_with_unused_login_profile_90_days_default_action
    enum        = local.iam_users_with_unused_login_profile_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_login_profile_90_days_enabled_actions
    enum        = local.iam_users_with_unused_login_profile_90_days_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_unused_login_profile_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_unused_login_profile_90_days
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

pipeline "correct_iam_users_with_unused_login_profile_90_days" {
  title       = "Correct IAM users with unused login profile from 90 days or more"
  description = "Runs corrective action to delete IAM users login profile that have been unused for 90 days or more."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                         = string
      user_name                     = string
      password_last_used            = string
      password_last_used_in_days    = string
      password_last_changed_in_days = string
      password_last_changed         = string
      account_id                    = string
      conn                          = string
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
    default     = var.iam_users_with_unused_login_profile_90_days_default_action
    enum        = local.iam_users_with_unused_login_profile_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_login_profile_90_days_enabled_actions
    enum        = local.iam_users_with_unused_login_profile_90_days_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user(s) login profile that have been unused for 90 days."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_unused_login_profile_90_days
    args = {
      title                         = each.value.title
      user_name                     = each.value.user_name
      password_last_used            = each.value.password_last_used
      password_last_changed         = each.value.password_last_changed
      password_last_used_in_days    = each.value.password_last_used_in_days
      password_last_changed_in_days = each.value.password_last_changed_in_days
      conn                          = connection.aws[each.value.conn]
      notifier                      = param.notifier
      notification_level            = param.notification_level
      approvers                     = param.approvers
      default_action                = param.default_action
      enabled_actions               = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_unused_login_profile_90_days" {
  title       = "Correct one IAM user with unused login profile from 90 days or more"
  description = "Runs corrective action to delete a IAM user login profile that have been unused for 90 days or more."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "password_last_used" {
    type        = string
    description = "The date when the IAM user's password was last used."
  }

  param "password_last_used_in_days" {
    type        = string
    description = "The number of days since the IAM user's password was last used."
  }

  param "password_last_changed_in_days" {
    type        = string
    description = "The number of days since the IAM user's password was last changed."
  }

  param "password_last_changed" {
    type        = string
    description = "The date when the IAM user's password was last changed."
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
    default     = var.iam_users_with_unused_login_profile_90_days_default_action
    enum        = local.iam_users_with_unused_login_profile_90_days_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_login_profile_90_days_enabled_actions
    enum        = local.iam_users_with_unused_login_profile_90_days_enabled_actions_enum
  }

  step "transform" "detect_msg" {
    value = <<-EOT
      ${param.password_last_used != "Never Used" ?
    format("Detected IAM user %s with password last used on %s (%s days).", param.user_name, param.password_last_used, param.password_last_used_in_days) :
  format("Detected IAM user %s with password never used and last changed on %s (%s days ).", param.user_name, param.password_last_changed, param.password_last_changed_in_days)}
    EOT
}

step "pipeline" "respond" {
  pipeline = detect_correct.pipeline.correction_handler
  args = {
    notifier           = param.notifier
    notification_level = param.notification_level
    approvers          = param.approvers
    detect_msg         = step.transform.detect_msg.value
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
          text     = "Skipped IAM user ${param.title}."
        }
        success_msg = ""
        error_msg   = ""
      },
      "delete_user_login_profile_unused_90_days" = {
        label        = "Delete IAM user login profile unsued from 90 days or more"
        value        = "delete_user_login_profile_unused_90_days"
        style        = local.style_alert
        pipeline_ref = pipeline.delete_user_login_profile
        pipeline_args = {
          user_name = param.user_name
          conn      = param.conn
        }
        success_msg = "Deleted IAM user ${param.title} login profile."
        error_msg   = "Error deleting IAM user ${param.title} login profile."
      }
    }
  }
}
}
