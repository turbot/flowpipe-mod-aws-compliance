locals {
  iam_users_with_access_key_during_initial_user_setup_query = <<-EOQ
    select
      concat(k.access_key_id, ' [', k.account_id, ']') as title,
      k.access_key_id,
      k.user_name,
      k.create_date as key_creation_date,
      u.create_date as user_creation_date,
      k.access_key_last_used_date,
      k.sp_connection_name as conn
    from
      aws_iam_access_key as k
      join aws_iam_user as u on u.name = k.user_name and (extract(day from now() - k.create_date)) = (extract(day from now() - u.create_date))
      join aws_iam_credential_report as r on r.user_name = u.name
    where
      access_key_last_used_date is null
      and password_enabled;
  EOQ
}

variable "iam_users_with_access_key_during_initial_user_setup_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_during_initial_user_setup_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_during_initial_user_setup_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_access_key_during_initial_user_setup_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_access_key_created_during_initial_user_setup"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_access_key_during_initial_user_setup" {
  title       = "Detect & correct IAM users with access key created during initial user setup"
  description = "Detects IAM users with access key created during initial user setup."
  tags        = local.iam_common_tags

  enabled  = var.iam_users_with_access_key_during_initial_user_setup_trigger_enabled
  schedule = var.iam_users_with_access_key_during_initial_user_setup_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_access_key_during_initial_user_setup_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_access_key_during_initial_user_setup
    args = {
      items = self.inserted_rows
    }
  }

}

pipeline "detect_and_correct_iam_users_with_access_key_during_initial_user_setup" {
  title       = "Detect & correct IAM users with access key created during initial user setup"
  description = "Detects IAM users with access key created during initial user setup."
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_users_with_access_key_during_initial_user_setup_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_during_initial_user_setup_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_access_key_during_initial_user_setup_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_access_key_during_initial_user_setup
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

pipeline "correct_iam_users_with_access_key_during_initial_user_setup" {
  title       = "Correct IAM users with access key created during initial user setup"
  description = "Runs corrective action to delete access key for IAM user created during initial user setup."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title             = string
      access_key_id     = string
      key_creation_date = string
      user_name         = string
      conn              = string
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
    default     = var.iam_users_with_access_key_during_initial_user_setup_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_during_initial_user_setup_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user access key(s) created during initial user setup."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_users_with_access_key_during_initial_user_setup
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      access_key_id      = each.value.access_key_id
      key_creation_date  = each.value.key_creation_date
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_users_with_access_key_during_initial_user_setup" {
  title       = "Correct one IAM user with access key created during initial user setup"
  description = "Runs corrective action to deleteaccess key for a IAM user with access key created during initial user setup."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
  }

  param "user_name" {
    type        = string
    description = "The name of the user."
  }

  param "key_creation_date" {
    type        = string
    description = "The creation date of IAM access key."
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
    default     = var.iam_users_with_access_key_during_initial_user_setup_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_access_key_during_initial_user_setup_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.user_name} access key ${param.access_key_id} created during initial user setup (${param.key_creation_date})."
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
            text     = "Skipped IAM user ${param.user_name} access key ${param.access_key_id} created on ${param.key_creation_date}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_access_key_created_during_initial_user_setup" = {
          label        = "Delete IAM user ${param.user_name} access key ${param.access_key_id} created during initial user setup"
          value        = "delete_access_key_created_during_initial_user_setup"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.delete_iam_access_key
          pipeline_args = {
            user_name     = param.user_name
            access_key_id = param.access_key_id
            conn          = param.conn
          }
          success_msg = "Deleted IAM user ${param.user_name} access key ${param.access_key_id} created during initial user setup ${param.key_creation_date}."
          error_msg   = "Error deleting IAM user ${param.user_name} access key ${param.access_key_id} created during initial user setup ${param.key_creation_date}."
        }
      }
    }
  }
}
