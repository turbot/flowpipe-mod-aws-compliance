locals {
  iam_account_password_policy_no_one_number_query = <<-EOQ
    select
      account_id as title,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_account_password_policy
    where
      require_numbers = false
      or require_numbers is null
  EOQ
}

trigger "query" "detect_and_correct_iam_account_password_policy_no_one_number" {
  title         = "Detect & Correct IAM Account Password Policy No One Number"
  description   = "Detects IAM account password policies that do not require at least one number and updates them."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_account_password_policy_no_one_number_trigger_enabled
  schedule = var.iam_account_password_policy_no_one_number_trigger_schedule
  database = var.database
  sql      = local.iam_account_password_policy_no_one_number_query

  capture "insert" {
    pipeline = pipeline.correct_iam_account_password_policy_no_one_number
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_account_password_policy_no_one_number" {
  title         = "Detect & Correct IAM Account Password Policy No One Number"
  description   = "Detects IAM account password policies that do not require at least one number and updates them."
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
    default     = var.iam_account_password_policy_no_one_number_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_one_number_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_account_password_policy_no_one_number_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_account_password_policy_no_one_number
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

pipeline "correct_iam_account_password_policy_no_one_number" {
  title         = "Correct IAM Account Password Policy No One Number"
  description   = "Runs corrective action on a collection of IAM account password policies that do not require at least one number."
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
    default     = var.iam_account_password_policy_no_one_number_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_one_number_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM account password policies with no requirement for at least one number."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.account_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_no_one_number
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

pipeline "correct_one_iam_account_password_policy_no_one_number" {
  title         = "Correct one IAM Account Password Policy No One Number"
  description   = "Runs corrective action to update one IAM account password policy to require at least one number."
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
    default     = var.iam_account_password_policy_no_one_number_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policy_no_one_number_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account password policy with no requirement for at least one number ${param.title}."
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
            text     = "Skipped IAM account password policy ${param.title} with no requirement for at least one number."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_password_policy_require_numbers" = {
          label        = "Update Password Policy Require Numbers"
          value        = "update_password_policy_require_numbers"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_update_iam_account_password_policy
          pipeline_args = {
            require_numbers = true
            cred           = param.cred
          }
          success_msg = "Updated IAM account password policy ${param.title} to require at least one number."
          error_msg   = "Error updating IAM account password policy ${param.title}."
        }
      }
    }
  }
}

variable "iam_account_password_policy_no_one_number_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_account_password_policy_no_one_number_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "iam_account_password_policy_no_one_number_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "iam_account_password_policy_no_one_number_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_password_policy_require_numbers"]
}
