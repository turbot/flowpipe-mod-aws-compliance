locals {
  iam_users_with_inline_policy_attached_query = <<-EOQ
    select
      concat(i ->> 'PolicyName', ' [', account_id, ']') as title,
      i ->> 'PolicyName' as inline_policy_name,
      name as user_name,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_user,
      jsonb_array_elements(inline_policies) as i;
  EOQ
}

variable "iam_users_with_inline_policy_attached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_users_with_inline_policy_attached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_users_with_inline_policy_attached_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_with_inline_policy_attached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_inline_policy"]
}

trigger "query" "detect_and_correct_iam_users_with_inline_policy_attached" {
  title         = "Detect & correct IAM users with inline policy"
  description   = "Detects IAM user with inline policy and deletes them."

  enabled  = var.iam_users_with_inline_policy_attached_trigger_enabled
  schedule = var.iam_users_with_inline_policy_attached_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_inline_policy_attached_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_inline_policy_attached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_inline_policy_attached" {
  title         = "Detect & correct IAM users with inline policy"
  description   = "Detects IAM user inline policy and deletes them."

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
    default     = var.iam_users_with_inline_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_inline_policy_attached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_inline_policy_attached
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

pipeline "correct_iam_users_with_inline_policy_attached" {
  title         = "Delete IAM user inline policy"
  description   = "Runs corrective action to delete IAM user inline policy."

  param "items" {
    type = list(object({
      title          = string
      user_name        = string
      inline_policy_name    = string
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
    default     = var.iam_users_with_inline_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} inline policy attached to IAM user."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_users_with_inline_policy_attached
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      inline_policy_name = each.value.inline_policy_name
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_users_with_inline_policy_attached" {
  title         = "Correct one IAM user with inline policy"
  description   = "Runs corrective action to delete one IAM user inline policy."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "inline_policy_name" {
    type        = string
    description = "The name of the inline policy."
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
    default     = var.iam_users_with_inline_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.user_name} inline policy ${param.title}."
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
            text     = "Skipped IAM user ${param.user_name} inline policy ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_inline_policy" = {
          label        = "Delete Inline Policy"
          value        = "delete_inline_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.delete_user_inline_policy
          pipeline_args = {
            user_name           = param.user_name
            inline_policy_name  = param.inline_policy_name
            cred                = param.cred
          }
          success_msg = "Deleted IAM user ${param.user_name} inline policy ${param.title}."
          error_msg   = "Error deleting IAM user ${param.user_name} inline policy ${param.title}."
        }
      }
    }
  }
}

pipeline "delete_user_inline_policy" {
  title       = "Delete User Inline Policy"
  description = "Deletes the specified inline policy from the specified IAM user."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user from which to delete the policy."
  }

  param "inline_policy_name" {
    type        = string
    description = "The name of the inline policy to delete."
  }

  step "container" "delete_inline_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      [
        "iam",
        "delete-user-policy",
        "--user-name", param.user_name,
        "--policy-name", param.inline_policy_name
      ]
    )

    env = credential.aws[param.cred].env
  }
}