locals {
  kms_key_rotation_disabled_query = <<-EOQ
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

trigger "query" "detect_and_correct_kms_key_rotation_disabled" {
  title         = "Detect & Correct KMS Key Rotation Disabled"
  description   = "Detects KMS keys with key rotation disabled and enables key rotation."
  documentation = file("./kms/docs/a.md")
  tags          = merge(local.kms_common_tags, { class = "security" })

  enabled  = var.kms_key_rotation_disabled_trigger_enabled
  schedule = var.kms_key_rotation_disabled_trigger_schedule
  database = var.database
  sql      = local.kms_key_rotation_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_kms_key_rotation_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_kms_key_rotation_disabled" {
  title         = "Detect & Correct KMS Key Rotation Disabled"
  description   = "Detects KMS keys with key rotation disabled and enables key rotation."
  documentation = file("./kms/docs/b.md")
  tags          = merge(local.kms_common_tags, { class = "security", type = "featured" })

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
    sql      = local.kms_key_rotation_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_kms_key_rotation_disabled
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

pipeline "correct_kms_key_rotation_disabled" {
  title         = "Correct KMS Key Rotation Disabled"
  description   = "Enables key rotation for KMS keys that have it disabled."
  documentation = file("./kms/docs/c.md")
  tags          = merge(local.kms_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title  = string
      key_id = string
      region = string
      cred   = string
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
    default     = var.kms_key_rotation_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.kms_key_rotation_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} KMS keys with key rotation disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.key_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_kms_key_rotation_disabled
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

pipeline "correct_one_kms_key_rotation_disabled" {
  title         = "Correct One KMS Key Rotation Disabled"
  description   = "Enables key rotation for a single KMS key."
  documentation = file("./kms/docs/d.md")
  tags          = merge(local.kms_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = "The title of the KMS key."
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
            send     = param.notification_level == local.level_verbose
            text     = "Skipped DynamoDB table ${param.title} with deletion protection disabled."
          }
          success_msg = ""
          error_msg   = ""
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
