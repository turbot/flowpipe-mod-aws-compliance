locals {
  iam_users_with_inline_policy_attached_query = <<-EOQ
    select
      concat(i ->> 'PolicyName', ' [', account_id, ']') as title,
      i ->> 'PolicyName' as inline_policy_name,
      name as user_name,
      account_id,
      sp_connection_name as conn
    from
      aws_iam_user,
      jsonb_array_elements(inline_policies) as i;
  EOQ

  iam_users_with_inline_policy_attached_default_action_enum  = ["notify", "skip", "delete_inline_policy"]
  iam_users_with_inline_policy_attached_enabled_actions_enum = ["skip", "delete_inline_policy"]
}

variable "iam_users_with_inline_policy_attached_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_inline_policy_attached_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_inline_policy_attached_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "delete_inline_policy"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_users_with_inline_policy_attached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_inline_policy"]
  enum        = ["skip", "delete_inline_policy"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_users_with_inline_policy_attached" {
  title       = "Detect & correct IAM users with inline policy"
  description = "Detects IAM user with inline policy and deletes them."
  tags        = local.iam_common_tags

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
  title       = "Detect & correct IAM users with inline policy"
  description = "Detects IAM user inline policy and deletes them."
  tags        = local.iam_common_tags

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_users_with_inline_policy_attached_default_action
    enum        = local.iam_users_with_inline_policy_attached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
    enum        = local.iam_users_with_inline_policy_attached_enabled_actions_enum
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
  title       = "Delete IAM user inline policy"
  description = "Runs corrective action to delete IAM user inline policy."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title              = string
      user_name          = string
      inline_policy_name = string
      conn               = string
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_users_with_inline_policy_attached_default_action
    enum        = local.iam_users_with_inline_policy_attached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
    enum        = local.iam_users_with_inline_policy_attached_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
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
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_users_with_inline_policy_attached" {
  title       = "Correct one IAM user with inline policy"
  description = "Runs corrective action to delete inline policy for a IAM user with inline policy attached."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_users_with_inline_policy_attached_default_action
    enum        = local.iam_users_with_inline_policy_attached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_inline_policy_attached_enabled_actions
    enum        = local.iam_users_with_inline_policy_attached_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user ${param.user_name} attached with inline policy ${param.title}."
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
          label        = "Delete IAM user inline policy"
          value        = "delete_inline_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.delete_user_inline_policy
          pipeline_args = {
            user_name          = param.user_name
            inline_policy_name = param.inline_policy_name
            conn               = param.conn
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
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
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

    env = connection.aws[param.conn].env
  }
}
