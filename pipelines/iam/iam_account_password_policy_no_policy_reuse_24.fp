locals {
  iam_account_password_policy_no_policy_reuse_24_query = <<-EOQ
    select
      account_id as title,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_account_password_policy
    where
      password_reuse_prevention < 24
      or password_reuse_prevention is null
  EOQ
}

trigger "query" "detect_and_correct_iam_account_password_policy_no_policy_reuse_24" {
  title         = "Detect & correct IAM Account Password Policy No Policy Reuse 24"
  description   = "Detects IAM account password policies that do not enforce a password reuse prevention policy of 24 and updates them."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_account_password_policy_no_policy_reuse_24_trigger_enabled
  schedule = var.iam_account_password_policy_no_policy_reuse_24_trigger_schedule
  database = var.database
  sql      = local.iam_account_password_policy_no_policy_reuse_24_query

  capture "insert" {
    pipeline = pipeline.correct_iam_account_password_policy_no_policy_reuse_24
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_account_password_policy_no_policy_reuse_24" {
  title         = "Detect & correct IAM Account Password Policy No Policy Reuse 24"
  description   = "Detects IAM account password policies that do not enforce a password reuse prevention policy of 24 and updates them."
  tags          = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.iam_account_password_policy_no_policy_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_policy_reuse_24_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_account_password_policy_no_policy_reuse_24_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_account_password_policy_no_policy_reuse_24
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

pipeline "correct_iam_account_password_policy_no_policy_reuse_24" {
  title         = "Correct IAM Account Password Policy No Policy Reuse 24"
  description   = "Runs corrective action on a collection of IAM account password policies that do not enforce a password reuse prevention policy of 24."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title          = string
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
    default     = var.iam_account_password_policy_no_policy_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_policy_reuse_24_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM account password policies with no password reuse prevention policy of 24."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.account_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_no_policy_reuse_24
    args = {
      title              = each.value.title
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

pipeline "correct_one_iam_account_password_policy_no_policy_reuse_24" {
  title         = "Correct one IAM Account Password Policy No Policy Reuse 24"
  description   = "Runs corrective action to update one IAM account password policy to enforce a password reuse prevention policy of 24."
  tags          = merge(local.iam_common_tags, { class = "security" })

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
    default     = var.iam_account_password_policy_no_policy_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_policy_reuse_24_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account password policy with no password reuse prevention policy of 24 for ${param.title}."
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
            text     = "Skipped IAM account password policy for ${param.title} with no password reuse prevention policy of 24."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_password_policy_reuse_prevention" = {
          label        = "Update Password Policy Reuse Prevention"
          value        = "update_password_policy_reuse_prevention"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.update_iam_account_password_policy
          pipeline_args = {
            password_reuse_prevention = 24
            cred                     = param.cred
          }
          success_msg = "Updated IAM account password policy for ${param.title} to enforce a password reuse prevention policy of 24."
          error_msg   = "Error updating IAM account password policy ${param.title}."
        }
      }
    }
  }
}

variable "iam_account_password_policy_no_policy_reuse_24_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_account_password_policy_no_policy_reuse_24_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_account_password_policy_no_policy_reuse_24_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_account_password_policy_no_policy_reuse_24_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_password_policy_reuse_prevention"]
}
