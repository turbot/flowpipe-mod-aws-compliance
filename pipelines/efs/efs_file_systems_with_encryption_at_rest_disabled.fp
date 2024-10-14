locals {
  efs_file_systems_with_encryption_at_rest_disabled_query = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      name as file_system_name,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_efs_file_system
    where
      not encrypted;
  EOQ
}

variable "efs_file_systems_with_encryption_at_rest_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/EFS"
  }
}

variable "efs_file_systems_with_encryption_at_rest_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/EFS"
  }
}

variable "efs_file_systems_with_encryption_at_rest_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/EFS"
  }
}

variable "efs_file_systems_with_encryption_at_rest_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]

  tags = {
    folder = "Advanced/EFS"
  }
}

trigger "query" "detect_and_correct_efs_file_systems_with_encryption_at_rest_disabled" {
  title       = "Detect & correct EFS file systems with encryption at rest disabled"
  description = "Detect EFS file systems with encryption at rest disabled."
  tags        = local.efs_common_tags

  enabled  = var.efs_file_systems_with_encryption_at_rest_disabled_trigger_enabled
  schedule = var.efs_file_systems_with_encryption_at_rest_disabled_trigger_schedule
  database = var.database
  sql      = local.efs_file_systems_with_encryption_at_rest_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_efs_file_systems_with_encryption_at_rest_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_efs_file_systems_with_encryption_at_rest_disabled" {
  title       = "Detect & correct EFS file systems with encryption at rest disabled"
  description = "Detect EFS file systems with encryption at rest disabled."
  tags        = merge(local.efs_common_tags, { recommended = "true" })

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
    default     = var.efs_file_systems_with_encryption_at_rest_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.efs_file_systems_with_encryption_at_rest_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.efs_file_systems_with_encryption_at_rest_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_efs_file_systems_with_encryption_at_rest_disabled
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

pipeline "correct_efs_file_systems_with_encryption_at_rest_disabled" {
  title       = "Correct EFS file systems with encryption at rest disabled"
  description = "Detect EFS file systems with encryption at rest disabled."
  tags        = merge(local.efs_common_tags, { type = "internal" })

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
    default     = var.efs_file_systems_with_encryption_at_rest_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.efs_file_systems_with_encryption_at_rest_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EFS file system(s) with encryption at rest disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = notifier[param.notifier]
    text     = "Detected EFS file system ${each.value.title} with encryption at rest disabled."
  }
}
