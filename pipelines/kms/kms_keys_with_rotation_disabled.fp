locals {
  kms_keys_with_rotation_disabled_query = <<-EOQ
    select
      concat(id, ' [', account_id, '/', region, ']') as title,
      id as key_id,
      region,
      sp_connection_name as conn
    from
      aws_kms_key
    where
      key_manager = 'CUSTOMER'
      and key_rotation_enabled = false
      and origin != 'EXTERNAL'
      and key_state not in ('PendingDeletion', 'Disabled');
  EOQ
}

variable "kms_keys_with_rotation_disabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false
}

variable "kms_keys_with_rotation_disabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"
}

variable "kms_keys_with_rotation_disabled_default_action" {
  type        = string
  description = "The default action to use for detected items."
  default     = "skip"
}

variable "kms_keys_with_rotation_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_key_rotation"]
}

trigger "query" "detect_and_correct_kms_keys_with_rotation_disabled" {
  title       = "Detect & correct KMS keys with rotation disabled"
  description = "Detect KMS keys with rotation disabled and then enable rotation."

  enabled  = var.kms_keys_with_rotation_disabled_trigger_enabled
  schedule = var.kms_keys_with_rotation_disabled_trigger_schedule
  database = var.database
  sql      = local.kms_keys_with_rotation_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_kms_keys_with_rotation_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_kms_keys_with_rotation_disabled" {
  title       = "Detect & correct KMS keys with rotation disabled"
  description = "Detect KMS keys with rotation disabled and then enable rotation."

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
    default     = var.kms_keys_with_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_keys_with_rotation_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.kms_keys_with_rotation_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_kms_keys_with_rotation_disabled
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

pipeline "correct_kms_keys_with_rotation_disabled" {
  title       = "Correct KMS Keys with rotation disabled"
  description = "Enable rotation for KMS keys with rotation disabled."

  param "items" {
    type = list(object({
      title  = string
      key_id = string
      region = string
      conn   = string
    }))
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
    default     = var.kms_keys_with_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_keys_with_rotation_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} KMS key(s) with rotation disabled."
  }


  step "pipeline" "correct_item" {
    for_each        = { for item in param.items: item.key_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_correct_kms_key_with_rotation_disabled
    args = {
      title              = each.value.title
      key_id             = each.value.key_id
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_correct_kms_key_with_rotation_disabled" {
  title       = "Correct KMS key with rotation disabled"
  description = "Runs corrective action for a KMS key with rotation disabled."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "key_id" {
    type        = string
    description = "The ID of the KMS key."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    default     = var.kms_keys_with_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_keys_with_rotation_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected KMS key ${param.title} with rotation disabled."
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
            send     = param.notification_level == local.level_info
            text     = "Skipped KMS key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_key_rotation" = {
          label        = "Enable KMS key rotation"
          value        = "enable_key_rotation"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.enable_kms_key_rotation
          pipeline_args = {
            key_id = param.key_id
            region = param.region
            conn   = param.conn
          }
          success_msg = "Enabled key rotation for KMS key ${param.title}."
          error_msg   = "Error enabling key rotation for KMS key ${param.title}."
        }
      }
    }
  }
}

