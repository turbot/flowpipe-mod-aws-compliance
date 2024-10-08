locals {
  iam_root_user_with_access_key_query = <<-EOQ
    select
      concat(access_key_id, ' [', account_id, ']') as title,
      user_name,
      access_key_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_access_key
    where
      user_name = '<root_account>';
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
  default     = ["skip", "delete_root_user_access_key"]
}

trigger "query" "detect_and_correct_iam_root_user_with_access_key" {
  title         = "Detect & correct IAM root user with access keys"
  description   = "Detects IAM root user access keys and deletes them."

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
  title         = "Detect & correct IAM root user with access keys"
  description   = "Detects IAM root user access keys and deletes them."

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
  title         = "Correct IAM root user with access keys"
  description   = "Runs corrective action to delete IAM root user access keys."

  param "items" {
    type = list(object({
      title          = string
      user_id        = string
      access_key_id  = string
      region         = string
      cred           = string
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
    text     = "Detected ${length(param.items)} IAM root user access key(s)."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.access_key_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_root_user_access_key
    args = {
      title              = each.value.title
      user_id            = each.value.user_id
      access_key_id      = each.value.access_key_id
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

pipeline "correct_one_iam_root_user_access_key" {
  title         = "Correct IAM root user access key"
  description   = "Runs corrective action to delete IAM root user access key."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_id" {
    type        = string
    description = "The user ID of the IAM root user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM root user."
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
    default     = var.iam_root_user_with_access_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_user_with_access_key_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM root user access key ${param.title}."
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
            send     = param.notification_level == local.level_verbose
            text     = "Skipped IAM root user access key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_root_user_access_key" = {
          label        = "Delete IAM root access key ${param.access_key_id}"
          value        = "delete_root_user_access_key"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.delete_iam_access_key
          pipeline_args = {
            access_key_id = param.access_key_id
            region        = param.region
            cred          = param.cred
          }
          success_msg = "Deleted IAM root user access key ${param.title}."
          error_msg   = "Error deleting IAM root user access key ${param.title}."
        }
      }
    }
  }
}