locals {
  iam_root_users_with_access_keys_query = <<-EOQ
    select
      concat('<root_account>', ' [', account_id, ']') as title,
      (account_access_keys_present)::text as account_access_keys_present,
      sp_connection_name as conn
    from
      aws_iam_account_summary
    where
      account_access_keys_present > 0;
  EOQ
}

variable "iam_root_users_with_access_keys_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_users_with_access_keys_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_root_users_with_access_keys" {
  title       = "Detect & correct IAM root users with access keys"
  description = "Detects IAM root users with access keys."
  tags        = local.iam_common_tags

  enabled  = var.iam_root_users_with_access_keys_trigger_enabled
  schedule = var.iam_root_users_with_access_keys_trigger_schedule
  database = var.database
  sql      = local.iam_root_users_with_access_keys_query

  capture "insert" {
    pipeline = pipeline.correct_iam_root_users_with_access_keys
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_users_with_access_keys" {
  title       = "Detect & correct IAM root users with access keys"
  description = "Detects IAM root users with access keys."
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

  step "query" "detect" {
    database = param.database
    sql      = local.iam_root_users_with_access_keys_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_root_users_with_access_keys
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_iam_root_users_with_access_keys" {
  title       = "Correct IAM root users with access keys"
  description = "Send notifications for IAM root users with access keys."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                       = string
      account_access_keys_present = string
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
    text     = "Detected ${length(param.items)} IAM root user(s) with access keys."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected IAM ${each.value.title} with ${each.value.account_access_keys_present} access key(s)."
  }
}
