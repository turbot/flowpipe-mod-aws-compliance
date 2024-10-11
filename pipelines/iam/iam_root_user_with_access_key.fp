locals {
  iam_root_user_with_access_key_query = <<-EOQ
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

variable "iam_root_user_with_access_key_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_access_key_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_access_key_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_access_key_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_root_user_with_access_key" {
  title         = "Detect & correct IAM root user with access keys"
  description   = "Detects IAM root user with access keys."
  tags          = local.iam_common_tags

  enabled  = var.iam_root_user_with_access_key_trigger_enabled
  schedule = var.iam_root_user_with_access_key_trigger_schedule
  database = var.database
  sql      = local.iam_root_user_with_access_key_query

  capture "insert" {
    pipeline = pipeline.correct_iam_root_user_with_access_key
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_user_with_access_key" {
  title       = "Detect & correct IAM root user with access keys"
  description = "Detects IAM root user with access keys."
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
    default     = var.iam_root_user_with_access_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_access_key_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_root_user_with_access_key_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_root_user_with_access_key
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

pipeline "correct_iam_root_user_with_access_key" {
  title       = "Correct IAM root user with access key"
  description = "Detect IAM root user with access key"
  tags          = merge(local.iam_common_tags, { type = "internal" })

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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_root_user_with_access_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_access_key_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM root user with access key."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected IAM ${each.value.title} with ${each.value.account_access_keys_present} access key(s)."
  }
}
