locals {
  iam_root_users_last_used_90_days_query = <<-EOQ
    select
      concat(user_name, ' [', account_id, ']') as title,
      account_id,
      sp_connection_name as conn,
      case when password_last_used is not null then concat('used on ', password_last_used::text) else 'never used' end as password_last_used,
      case when access_key_1_last_used_date is not null then concat('used on ', access_key_1_last_used_date::text )else 'never used' end as access_key_1_last_used_date,
      case when access_key_2_last_used_date is not null then concat('used on ',access_key_2_last_used_date::text )else 'never used' end as access_key_2_last_used_date
    from
      aws_iam_credential_report
    where
      user_name = '<root_account>'
      and (
        password_last_used >= (current_date - interval '90' day)
        or access_key_1_last_used_date <= (current_date - interval '90' day)
        or access_key_2_last_used_date <= (current_date - interval '90' day)
    );
  EOQ
}

variable "iam_root_users_last_used_90_days_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_users_last_used_90_days_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_root_users_last_used_90_days" {
  title       = "Detect & correct IAM root users last used in 90 days or more"
  description = "Detect IAM root users last used in 90 days or more."
  tags          = local.iam_common_tags

  enabled  = var.iam_root_users_last_used_90_days_trigger_enabled
  schedule = var.iam_root_users_last_used_90_days_trigger_schedule
  database = var.database
  sql      = local.iam_root_users_last_used_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_root_users_last_used_90_days
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_users_last_used_90_days" {
  title       = "Detect & correct IAM root users last used in 90 days or more"
  description = "Detect IAM root users last used in 90 days or more."
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
    enum        = local.notification_level_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_root_users_last_used_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_root_users_last_used_90_days
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_iam_root_users_last_used_90_days" {
  title         = "Correct IAM root users last used in 90 days or more"
  description   = "Send notifications for IAM root users last used in 90 days or more."
  tags          = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                       = string
      password_last_used          = string
      access_key_1_last_used_date = string
      access_key_2_last_used_date = string
      conn                        = string
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
    text     = "Detected ${length(param.items)} IAM root user(s) used in last 90 days."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected IAM ${each.value.title} with password ${each.value.password_last_used} and access key 1 ${each.value.access_key_1_last_used_date} and access key 2 ${each.value.access_key_2_last_used_date}."
  }
}
