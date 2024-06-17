locals {
  iam_root_last_used = <<-EOQ
    select
      cred.account_id as title,
      cred.account_id,
      cred.user_name,
      ak1.access_key_id as access_key_id, 
      cred._ctx ->> 'connection_name' as cred
    from
      aws_iam_credential_report as cred
      join aws_iam_access_key as ak1 on cred.user_name = ak1.user_name and cred.account_id = ak1.account_id
    where
      cred.user_name = '<root_account>'
      and cred.password_last_used >= (current_date - interval '90' day)
      and cred.access_key_1_last_used_date <= (current_date - interval '90' day)
      and cred.access_key_2_last_used_date <= (current_date - interval '90' day);
  EOQ
}

trigger "query" "detect_and_correct_iam_root_last_used" {
  title       = "Detect and correct IAM root last used"
  description = "Detects and corrects IAM root last used"
  tags        = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_root_last_used_trigger_enabled
  schedule = var.iam_root_last_used_trigger_schedule
  database = var.database
  sql      = local.iam_root_last_used

  capture "insert" {
    pipeline = pipeline.correct_iam_root_last_used
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_root_last_used" {
  title       = "Detect and correct IAM root last used"
  description = "Detects and corrects IAM root last used"
  tags        = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.iam_root_last_used_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_last_used_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_root_last_used
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_root_last_used
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

pipeline "correct_iam_root_last_used" {
  title       = "Correct IAM root last used"
  description = "Corrects IAM root last used."
  tags        = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      user_name     = string
      access_key_id = string
      title         = string
      account_id    = string
      cred          = string
    }))
    description = local.description_items
  }

  param "old_password" {
    type        = string
    description = "The old password for the IAM user."
    default     = var.old_password
  }

  param "new_password" {
    type        = string
    description = "The new password for the IAM user."
    default     = var.new_password
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
    default     = var.iam_root_last_used_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_last_used_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM account password policies with no minimum length of 14."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.account_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_no_min_length_14
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      access_key_id      = each.value.access_key_id
      account_id         = each.value.account_id
      old_password       = param.old_password
      new_password       = param.new_password
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_root_last_used" {
  title       = "Correct one IAM root last used"
  description = "Corrects one IAM root last used."
  tags        = merge(local.iam_common_tags, { class = "security" })

  param "user_name" {
    type        = string
    description = "The user name of the IAM account."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM account."
  }

  param "title" {
    type        = string
    description = local.description_title
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "old_password" {
    type        = string
    description = "The old password for the IAM user."
    default     = var.old_password
  }

  param "new_password" {
    type        = string
    description = "The new password for the IAM user."
    default     = var.new_password
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
    default     = var.iam_root_last_used_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_root_last_used_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected that the password for IAM user ${param.user_name} is not updated and access key is not deleted."
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
            text     = "Skipped updating password and deleting access key for IAM user ${param.user_name}."
          }
          success_msg = "Skipped updating password and deleting access key for IAM user ${param.user_name}."
          error_msg   = "Failed to skip updating password and deleting access key for IAM user ${param.user_name}."
        },
        "update_password_and_delete_access_key" = {
          label        = "Update password and delete access key"
          value        = "update_password_and_delete_access_key"
          style        = local.style_alert
          pipeline_ref = pipeline.update_password_and_delete_access_key
          pipeline_args = {
            user_name     = param.user_name
            access_key_id = param.access_key_id
            old_password  = param.old_password
            new_password  = param.new_password
            cred          = param.cred
          }
          success_msg = "Updated password and deleted access key for IAM user ${param.user_name}."
          error_msg   = "Failed to update password and delete access key for IAM user ${param.user_name}."
        }
      }
    }
  }
}

pipeline "update_password_and_delete_access_key" {
  param "user_name" {
    type        = string
    description = "The user name of the IAM account."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM account."
  }

  param "old_password" {
    type        = string
    description = "The old password for the IAM user."
  }

  param "new_password" {
    type        = string
    description = "The new password for the IAM user."
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  step "pipeline" "update_password" {
    pipeline = local.aws_pipeline_change_iam_password
    args = {
      user_name    = param.user_name
      old_password = param.old_password
      new_password = param.new_password
      cred         = param.cred
    }
  }

  step "pipeline" "delete_access_key" {
    depends_on = [step.pipeline.update_password]
    pipeline = local.aws_pipeline_delete_iam_access_key
    args = {
      user_name     = param.user_name
      access_key_id = param.access_key_id
      cred          = param.cred
    }
  }
}

variable "old_password" {
  type        = string
  description = "The old password for the IAM user."
}

variable "new_password" {
  type        = string
  description = "The new password for the IAM user."
}

variable "iam_root_last_used_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_root_last_used_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "iam_root_last_used_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "iam_root_last_used_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_password_and_delete_access_key"]
}
