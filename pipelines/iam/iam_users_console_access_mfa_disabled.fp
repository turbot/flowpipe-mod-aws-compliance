locals {
  iam_users_console_access_mfa_disabled_query = <<-EOQ
    select
			concat(user_name, ' [', account_id, ']') as title,
			user_name,
			account_id,
			_ctx ->> 'connection_name' as cred
		from
			aws_iam_credential_report
		where
			password_enabled and not mfa_active;
  EOQ
}

variable "iam_users_console_access_mfa_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_users_console_access_mfa_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_users_console_access_mfa_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_console_access_mfa_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]
}

trigger "query" "detect_and_correct_iam_users_console_access_mfa_disabled" {
  title       = "Detect & correct IAM users with console access MFA disabled"
  description = "Detect IAM users with console access MFA disabled."

  enabled  = var.iam_users_console_access_mfa_disabled_trigger_enabled
  schedule = var.iam_users_console_access_mfa_disabled_trigger_schedule
  database = var.database
  sql      = local.iam_users_console_access_mfa_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_console_access_mfa_disabled
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_users_console_access_mfa_disabled
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_console_access_mfa_disabled" {
  title       = "Detect & correct IAM users with console access MFA disabled"
  description = "Detect IAM users with console access MFA disabled."

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
    default     = var.iam_users_console_access_mfa_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_console_access_mfa_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_console_access_mfa_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_console_access_mfa_disabled
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

pipeline "correct_iam_users_console_access_mfa_disabled" {
  title       = "Correct IAM users with console access MFA disabled"
  description = "Detect IAM users with console access MFA disabled."

  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
      region      = string
      cred        = string
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
    default     = var.iam_users_console_access_mfa_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_console_access_mfa_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM user(s) with console access MFA disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = notifier[param.notifier]
    text     = "Detected IAM user ${each.value.title} with console access MFA disabled."
  }
}
