locals {
  iam_users_with_console_access_mfa_disabled_query = <<-EOQ
    select
      concat(user_name, ' [', account_id, ']') as title,
      user_name,
      account_id,
      sp_connection_name as conn
    from
      aws_iam_credential_report
    where
      password_enabled and not mfa_active;
  EOQ
}

variable "iam_users_with_console_access_mfa_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_console_access_mfa_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_console_access_mfa_disabled" {
  title       = "Detect & correct IAM users with console access MFA disabled"
  description = "Detect IAM users with console access MFA disabled."
  tags        = local.iam_common_tags

  enabled  = var.iam_users_with_console_access_mfa_disabled_trigger_enabled
  schedule = var.iam_users_with_console_access_mfa_disabled_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_console_access_mfa_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_console_access_mfa_disabled
    args = {
      items = self.inserted_rows
    }
  }

}

pipeline "detect_and_correct_iam_users_with_console_access_mfa_disabled" {
  title       = "Detect & correct IAM users with console access MFA disabled"
  description = "Detect IAM users with console access MFA disabled."

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

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_console_access_mfa_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_console_access_mfa_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_iam_users_with_console_access_mfa_disabled" {
  title       = "Correct IAM users with console access MFA disabled"
  description = "Send notifications for IAM users with console access MFA disabled."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title = string
      conn  = string
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

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user(s) with console access MFA disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected IAM user ${each.value.title} with console access MFA disabled."
  }
}
