locals {
  iam_users_with_iam_policy_attached_query = <<-EOQ
		select
			concat(name, ' [', account_id, ']') as title,
			jsonb_array_elements_text(attached_policy_arns) as policy_arn,
			name as user_name,
      account_id,
      _ctx ->> 'connection_name' as cred
		from
			aws_iam_user
		where
			attached_policy_arns is not null
      and name = 'flowpipe-user-dummy';
  EOQ
}

variable "iam_users_with_iam_policy_attached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_users_with_iam_policy_attached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_users_with_iam_policy_attached_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_with_iam_policy_attached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "detach_iam_policy"]
}

trigger "query" "detect_and_correct_iam_users_with_iam_policy_attached" {
  title         = "Detect & correct IAM users with IAM policy attached"
  description   = "Detects IAM users with a specific policy attached and detaches that policy."

  enabled  = var.iam_users_with_iam_policy_attached_trigger_enabled
  schedule = var.iam_users_with_iam_policy_attached_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_iam_policy_attached_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_iam_policy_attached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_iam_policy_attached" {
  title         = "Detect & correct IAM users with IAM policy attached"
  description   = "Detects IAM users with a specific policy attached and detaches that policy."

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
    default     = var.iam_users_with_iam_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_iam_policy_attached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_iam_policy_attached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_iam_policy_attached
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

pipeline "correct_iam_users_with_iam_policy_attached" {
  title         = "Correct IAM users with IAM policy attached"
  description   = "Detaches IAM policies from IAM users with IAM policy attached."

  param "items" {
    type = list(object({
      title          = string
      user_name      = string
			policy_arn     = string
      account_id     = string
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
    default     = var.iam_users_with_iam_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_iam_policy_attached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM user(s) with the specified policy attached."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.policy_arn => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_iam_policy_attached
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
			policy_arn         = each.value.policy_arn
      account_id         = each.value.account_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_iam_policy_attached" {
  title         = "Detach Policy from One IAM User"
  description   = "Detaches IAM policies from a IAM user with IAM policy attached."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

 	param "policy_arn" {
    type        = string
    description = "The name of the IAM user."
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
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
    default     = var.iam_users_with_iam_policy_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_iam_policy_attached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user with the specified policy attached ${param.title}."
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
            text     = "Skipped detaching policy from IAM user ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_iam_policy" = {
          label        = "Detach IAM policy"
          value        = "detach_iam_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.detach_iam_users_with_iam_policy_attached
          pipeline_args = {
            user_name  = param.user_name
            policy_arn = param.policy_arn
            cred       = param.cred
          }
          success_msg = "Detached IAM policy from IAM user ${param.title}."
          error_msg   = "Error detaching policy from IAM user ${param.title}."
        }
      }
    }
  }
}

pipeline "detach_iam_users_with_iam_policy_attached" {
  title       = "Detach IAM User Policy"
  description = "Detaches the specified managed policy from the specified IAM user."

  param "cred" {
    type        = string
    description = "TO-DO"
    default     = "default"
  }

  param "user_name" {
    type        = string
    description = "TO-DO"
  }

  param "policy_arn" {
    type        = string
    description = "The Amazon Resource Name (ARN) of the IAM policy you want to detach."
  }

  step "container" "detach_iam_user_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "detach-user-policy",
      "--user-name", param.user_name,
      "--policy-arn", param.policy_arn,
    ]

    env = credential.aws[param.cred].env
  }
}