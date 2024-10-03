locals {
  iam_users_with_unused_credential_45_days_query = <<-EOQ
    with unused_access_keys as (
      select
        concat(u.name, ' [', u.account_id, ']') as title,
        access_key_id,
        u.name as user_name,
        u.account_id as account_id,
        u._ctx ->> 'connection_name' as cred
      from
        aws_iam_user as u
        join aws_iam_access_key as k on u.name = k.user_name and u.account_id = k.account_id and access_key_last_used_date < (current_date - interval '45' day)
    )
    select
      concat(u.name, ' [', u.account_id, ']') as title,
      coalesce(k.access_key_id, concat(u.name, '_not_unused')) as access_key_id,
      u.name as user_name,
      u._ctx ->> 'connection_name' as cred,
      case
        when
          r.password_enabled and r.password_last_used is null and r.password_last_changed < (current_date - interval '45' day)
          or r.password_enabled and r.password_last_used < (current_date - interval '45' day) then true else false
      end as password_unused
    from
      aws_iam_user as u
      left join unused_access_keys as k on k.user_name = u.name and u.account_id = k.account_id
      left join aws_iam_credential_report as r on r.user_name = u.name and u.account_id = r.account_id
    where
      k.access_key_id is not null or (r.password_enabled and r.password_last_used is null and r.password_last_changed < (current_date - interval '45' day)
      or r.password_enabled and r.password_last_used < (current_date - interval '45' day));
  EOQ
}

variable "iam_users_with_unused_credential_45_days_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_users_with_unused_credential_45_days_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_users_with_unused_credential_45_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_with_unused_credential_45_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "deactivate_credential"]
}

trigger "query" "detect_and_correct_iam_users_with_unused_credential_45_days" {
  title         = "Detect & correct IAM users with unused credential from 45 days or more"
  description   = "Detects IAM users credential that have been unused for 45 days or more and deactivates them."

  enabled  = var.iam_users_with_unused_credential_45_days_trigger_enabled
  schedule = var.iam_users_with_unused_credential_45_days_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_unused_credential_45_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_unused_credential_45_days
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_users_with_unused_credential_45_days
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_unused_credential_45_days" {
  title         = "Detect & correct IAM users with unused credential from 45 days or more"
  description   = "Detects IAM users credential that have been unused for 45 days or more and deactivates them."

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
    default     = var.iam_users_with_unused_credential_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_credential_45_days_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_unused_credential_45_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_unused_credential_45_days
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

pipeline "correct_iam_users_with_unused_credential_45_days" {
  title         = "Correct IAM users with unused credential from 45 days or more"
  description   = "Runs corrective action to deactivate IAM users credential that have been unused for 45 days or more."

  param "items" {
    type = list(object({
      title           = string
      user_name       = string
      account_id      = string
      access_key_id   = string
      password_unused = bool
      cred            = string
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
    default     = var.iam_users_with_unused_credential_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_credential_45_days_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM user credentials that have been unused for 45 days."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.access_key_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_unused_credential_45_days
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      access_key_id      = each.value.access_key_id
      password_unused    = each.value.password_unused
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_unused_credential_45_days" {
  title         = "Correct IAM user with unused credential from 45 days or more"
  description   = "Runs corrective action to deactivate IAM user credential that have been unused for 45 days or more."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "password_unused" {
    type        = bool
    description = "The name of the IAM user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
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
    default     = var.iam_users_with_unused_credential_45_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_unused_credential_45_days_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.title} credential that has been unused for 45 days."
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
            text     = "Skipped IAM user credential ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "deactivate_credential" = {
          label        = "Deactivate user credential"
          value        = "deactivate_credential"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_access_key_and_disable_console_access
          pipeline_args = {
            user_name       = param.user_name
            password_unused = param.password_unused
            access_key_id   = param.access_key_id
            cred            = param.cred
          }
          success_msg = "Deactivated IAM user ${param.title} credential."
          error_msg   = "Error deactivating IAM user ${param.title} credential."
        }
      }
    }
  }
}

pipeline "deactivate_access_key_and_disable_console_access" {
  title       = "Deactivate Access Key and Disable Console Access"
  description = "Deactivates the IAM user's access key and disables console access by deleting the login profile."

  param "cred" {
    type        = string
    description =  local.description_credential
    default     = "default"
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "password_unused" {
    type        = bool
    description = "Indicates whether the user's password has not been used for the last 45 days or more."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
  }

  step "container" "deactivate_access_key" {
    if = param.access_key_id != "${param.user_name}_not_unused"
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "update-access-key",
      "--access-key-id", param.access_key_id,
      "--status", "Inactive",
      "--user-name", param.user_name
    ]

    env = credential.aws[param.cred].env
  }

  step "container" "delete_login_profile" {
    if = param.password_unused
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "delete-login-profile",
      "--user-name", param.user_name
    ]

    env = credential.aws[param.cred].env
  }

}
