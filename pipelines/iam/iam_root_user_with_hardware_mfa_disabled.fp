locals {
  iam_root_user_with_hardware_mfa_disabled_query = <<-EOQ
    select
      concat('<root_account>', ' [', s.account_id, ']') as title,
      s.account_id,
      s._ctx ->> 'connection_name' as cred
    from
      aws_iam_account_summary as s
      left join aws_iam_virtual_mfa_device as d on (d.user ->> 'Arn') = concat('arn:', s.partition, ':iam::', s.account_id, ':root')
    where
      s.account_mfa_enabled = false or d.serial_number is not null;
  EOQ
}

variable "iam_root_user_with_hardware_mfa_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_hardware_mfa_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_hardware_mfa_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_root_user_with_hardware_mfa_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_root_user_with_hardware_mfa_disabled" {
  title       = "Detect & correct IAM root user with hardware MFA disabled"
  description = "Detect IAM root user with hardware MFA disabled."
  tags          = local.iam_common_tags

  enabled  = var.iam_root_user_with_hardware_mfa_disabled_trigger_enabled
  schedule = var.iam_root_user_with_hardware_mfa_disabled_trigger_schedule
  database = var.database
  sql      = local.iam_root_user_with_hardware_mfa_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_iam_root_user_with_hardware_mfa_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_user_with_hardware_mfa_disabled" {
  title       = "Detect & correct IAM root user with hardware MFA disabled"
  description = "Detect IAM root user with hardware MFA disabled."
  tags          = local.iam_common_tags

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
    default     = var.iam_root_user_with_hardware_mfa_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_hardware_mfa_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_root_user_with_hardware_mfa_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_root_user_with_hardware_mfa_disabled
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

pipeline "correct_iam_root_user_with_hardware_mfa_disabled" {
  title         = "Correct IAM root user with hardware MFA disabled"
  description   = "Detect IAM root user with hardware MFA disabled."
  tags          = merge(local.iam_common_tags, { type = "internal" })

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
    default     = var.iam_root_user_with_hardware_mfa_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_hardware_mfa_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM root user with hardware MFA disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = notifier[param.notifier]
    text     = "Detected IAM ${each.value.title} with hardware MFA disabled."
  }
}
