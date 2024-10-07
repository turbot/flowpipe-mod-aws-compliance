locals {
  iam_groups_with_unrestricted_cloudshell_full_access_query = <<-EOQ
    select
      concat(name, ' [', account_id,  ']') as title,
      name as group_name,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_group
    where
      attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
  EOQ
}

variable "iam_groups_with_unrestricted_cloudshell_full_access_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_groups_with_unrestricted_cloudshell_full_access_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_groups_with_unrestricted_cloudshell_full_access_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_groups_with_unrestricted_cloudshell_full_access_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "detach_group_cloudshell_full_access_policy"]
}

trigger "query" "detect_and_correct_iam_groups_with_unrestricted_cloudshell_full_access" {
  title         = "Detect & correct IAM groups with unrestricted CloudShellFullAccess policy"
  description   = "Detects IAM groups with unrestricted CloudShellFullAccess policy attached and then detaches that policy."

  enabled  = var.iam_groups_with_unrestricted_cloudshell_full_access_trigger_enabled
  schedule = var.iam_groups_with_unrestricted_cloudshell_full_access_trigger_schedule
  database = var.database
  sql      = local.iam_groups_with_unrestricted_cloudshell_full_access_query

  capture "insert" {
    pipeline = pipeline.correct_iam_groups_with_unrestricted_cloudshell_full_access
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_groups_with_unrestricted_cloudshell_full_access
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_groups_with_unrestricted_cloudshell_full_access" {
  title         = "Detect & correct IAM groups with unrestricted CloudShellFullAccess policy"
  description   = "Detects IAM groups with unrestricted CloudShellFullAccess policy attached and detaches that policy."

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
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_groups_with_unrestricted_cloudshell_full_access_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_groups_with_unrestricted_cloudshell_full_access
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

pipeline "correct_iam_groups_with_unrestricted_cloudshell_full_access" {
  title         = "Correct IAM groups with unrestricted CloudShellFullAccess policy"
  description   = "Runs corrective action to detach the CloudShellFullAccess policy from IAM groups."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title          = string
      group_name      = string
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
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM group(s) with unrestricted CloudShellFullAccess policy attached."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_group_with_unrestricted_cloudshell_full_access
    args = {
      title              = each.value.title
      group_name          = each.value.group_name
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

pipeline "correct_iam_group_with_unrestricted_cloudshell_full_access" {
  title         = "Correct IAM group with unrestricted CloudShellFullAccess policy"
  description   = "Runs corrective action to detach the unrestricted CloudShellFullAccess policy from IAM group."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "group_name" {
    type        = string
    description = "The name of the IAM group."
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
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_with_unrestricted_cloudshell_full_access_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM group ${param.title} atttached with the policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess`."
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
            text     = "Skipped IAM group ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_group_cloudshell_full_access_policy" = {
          label        = "Detach cloudshell full access policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess`"
          value        = "detach_group_cloudshell_full_access_policy"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.detach_iam_group_policy
          pipeline_args = {
            group_name   = param.group_name
            policy_arn  = "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
            cred        = param.cred
          }
          success_msg = "Detached policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess` from IAM group ${param.title}."
          error_msg   = "Error detaching policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess` from IAM group ${param.title}."
        }
      }
    }
  }
}
