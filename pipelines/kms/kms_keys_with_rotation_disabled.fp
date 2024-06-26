locals {
  kms_keys_with_rotation_disabled_query = <<-EOQ
    select
      concat(id, ' [', region, '/', account_id, ']') as title,
      id as key_id,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_kms_key
    where
      key_manager = 'CUSTOMER'
      and key_rotation_enabled = false
      and origin != 'EXTERNAL'
      and key_state not in ('PendingDeletion', 'Disabled');
  EOQ
}

trigger "query" "detect_and_correct_kms_keys_with_rotation_disabled" {
  title       = "Detect & correct KMS keys with rotation disabled"
  description = "Detects KMS Keys with rotation disabled and runs your chosen action."
  // // documentation = file("./kms/docs/detect_and_correct_kms_keys_with_rotation_disabled_trigger.md")
  tags          = merge(local.kms_common_tags, { class = "unused" })

  enabled  = var.kms_key_rotation_disabled_trigger_enabled
  schedule = var.kms_key_rotation_disabled_trigger_schedule
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
  description = "Detects KMS keys with rotation disabled and runs your chosen action."
  // // documentation = file("./kms/docs/detect_and_correct_kms_keys_with_rotation_disabled.md")
  // tags          = merge(local.kms_common_tags, { class = "unused", type = "featured" })

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
    default     = var.kms_key_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_key_rotation_disabled_enabled_actions
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
  title       = "Correct KMS keys with rotation disabled"
  description = "Executes corrective actions on KMS keys with rotation disabled."
  // // documentation = file("./kms/docs/correct_kms_keys_with_rotation_disabled.md")
  // tags          = merge(local.kms_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title  = string
      key_id = string
      region = string
      cred   = string
    }))
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
    default     = var.kms_key_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_key_rotation_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} KMS keys with key rotation disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.key_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_correct_kms_key_with_rotation_disabled
    args = {
      title              = each.value.title
      key_id             = each.value.key_id
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_correct_kms_key_with_rotation_disabled" {
  title       = "Correct one KMS key with rotation disabled"
  description = "Runs corrective action on a single KMS key with rotation disabled."
  // // documentation = file("./kms/docs/correct_one_correct_kms_key_with_rotation_disabled.md")
  // tags          = merge(local.kms_common_tags, { class = "unused" })

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
    default     = var.kms_key_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_key_rotation_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected key rotation disabled for KMS key ${param.title}."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == "verbose"
            text     = "Skipped enabling rotation for KMS key ${param.title}."
          }
          success_msg = "Skipped key rotation for KMS key ${param.title}."
          error_msg   = "Error skipping key rotation for KMS key ${param.title}."
        },
        "enable_rotation" = {
          label        = "Enable Key Rotation"
          value        = "enable_rotation"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_enable_kms_key_rotation
          pipeline_args = {
            key_id = param.key_id
            region = param.region
            cred   = param.cred
          }
          success_msg = "Enabled key rotation for KMS key ${param.title}."
          error_msg   = "Failed to enable key rotation for KMS key ${param.title}."
        }
      }
    }
  }
}

variable "kms_key_rotation_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "kms_key_rotation_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "kms_key_rotation_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "kms_key_rotation_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_rotation"]
}