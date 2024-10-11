locals {
  iam_users_with_unused_access_key_45_days_query = <<-EOQ
    select
      concat(u.name, ' [', u.account_id, ']') as title,
      k.access_key_id,
      u.name as user_name,
      u.sp_connection_name as conn,
      k.access_key_last_used_date,
      (extract(day from now() - k.access_key_last_used_date))::text as access_key_last_used_day  -- Extracts only the days part
    from
      aws_iam_user as u
      join aws_iam_access_key as k on u.name = k.user_name and u.account_id = k.account_id
      and access_key_last_used_date < (current_date - interval '45' day);
  EOQ
}

variable "iam_users_with_unused_access_key_45_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_access_key_45_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_access_key_45_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_unused_access_key_45_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "deactivate_user_access_key_unused_45_days"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_unused_access_key_45_days" {
  title         = "Detect & correct IAM users with unused access key from 45 days or more"
  description   = "Detects IAM users access key that have been unused for 45 days or more and deactivates them."
  tags          = local.iam_common_tags

  enabled  = var.iam_users_with_unused_access_key_45_days_trigger_enabled
  schedule = var.iam_users_with_unused_access_key_45_days_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_unused_access_key_45_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_unused_access_key_45_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_unused_access_key_45_days" {
  title         = "Detect & correct IAM users with unused access key from 45 days or more"
  description   = "Detects IAM users access key that have been unused for 45 days or more and deactivates them."
  tags          = local.iam_common_tags

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
    default     = var.iam_users_with_unused_access_key_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_access_key_45_days_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_unused_access_key_45_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_unused_access_key_45_days
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

pipeline "correct_iam_users_with_unused_access_key_45_days" {
  title         = "Correct IAM users with unused access key from 45 days or more"
  description   = "Runs corrective action to deactivate IAM users access key that have been unused for 45 days or more."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title                      = string
      user_name                  = string
      account_id                 = string
      access_key_last_used_date  = string
      access_key_last_used_day   = string
      access_key_id              = string
      conn                       = string
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
    default     = var.iam_users_with_unused_access_key_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_access_key_45_days_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user(s) access key that have been unused for 45 days or more."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.access_key_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_unused_access_key_45_days
    args = {
      title                     = each.value.title
      user_name                 = each.value.user_name
      access_key_id             = each.value.access_key_id
      access_key_last_used_date = each.value.access_key_last_used_date
      access_key_last_used_day  = each.value.access_key_last_used_day
      conn                      = connection.aws[each.value.conn]
      notifier                  = param.notifier
      notification_level        = param.notification_level
      approvers                 = param.approvers
      default_action            = param.default_action
      enabled_actions           = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_unused_access_key_45_days" {
  title         = "Correct one IAM user with unused access key from 45 days or more"
  description   = "Runs corrective action to deactivate a IAM user access key that have been unused for 45 days or more."
  tags          = merge(local.iam_common_tags, { type = "internal" })

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

   param "access_key_last_used_date" {
    type        = string
    description = "The access key ID of the IAM user."
  }

  param "access_key_last_used_day" {
    type        = string
    description = "The number of days since the IAM user's access key was last used."
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
    default     = var.iam_users_with_unused_access_key_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_access_key_45_days_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.user_name} with access key ${param.access_key_id} last used ${param.access_key_last_used_date} (${param.access_key_last_used_day} days)."
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
            text     = "Skipped IAM user ${param.title} access key ${param.access_key_id}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "deactivate_user_access_key_unused_45_days" = {
          label        = "Deactivate user access key unused from 45 days or more"
          value        = "deactivate_user_access_key_unused_45_days"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_user_access_key
          pipeline_args = {
            user_name      = param.user_name
            access_key_id  = param.access_key_id
            conn           = param.conn
          }
          success_msg = "Deactivated IAM user ${param.title} access key ${param.access_key_id}."
          error_msg   = "Error deactivating IAM user ${param.title} access key ${param.access_key_id}."
        }
      }
    }
  }
}

pipeline "deactivate_user_access_key" {
  title       = "Deactivate IAM user access Key"
  description = "Deactivates the IAM user's access key."

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
  }

  step "container" "deactivate_user_access_key" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "update-access-key",
      "--access-key-id", param.access_key_id,
      "--status", "Inactive",
      "--user-name", param.user_name
    ]

    env = connection.aws[param.conn].env
  }
}
