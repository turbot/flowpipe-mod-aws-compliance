locals {
  iam_root_user_with_access_key_query = <<-EOQ
    select
      concat('<root_account>', ' [', account_id, ']') as title,
      (account_access_keys_present)::text as account_access_keys_present,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_account_summary
    where
      account_access_keys_present > 0;
  EOQ
}

variable "iam_root_user_with_access_key_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_root_user_with_access_key_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_root_user_with_access_key_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_root_user_with_access_key_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]
}

trigger "query" "detect_and_correct_iam_root_user_with_access_key" {
  title         = "Detect & correct IAM root user with access keys"
  description   = "Detects IAM root user with access keys."

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

  capture "update" {
    pipeline = pipeline.correct_iam_root_user_with_access_key
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_user_with_access_key" {
  title       = "Detect & correct IAM root user with access keys"
  description = "Detects IAM root user with access keys."


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

  param "items" {
    type = list(object({
      title                       = string
      account_access_keys_present = string
      cred                        = string
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
    default     = var.iam_root_user_with_access_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_access_key_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM root user with access key."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = notifier[param.notifier]
    text     = "Detected IAM ${each.value.title} with ${each.value.account_access_keys_present} access key(s)."
  }
}
