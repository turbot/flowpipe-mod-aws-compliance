locals {
  iam_account_password_policies_without_max_password_age_90_days_query = <<-EOQ
    select
      account_id as title,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_account_password_policy
    where
      max_password_age < 90
      or max_password_age is null;
  EOQ
}

variable "iam_account_password_policies_without_max_password_age_90_days_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_account_password_policies_without_max_password_age_90_days_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_account_password_policies_without_max_password_age_90_days_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_account_password_policies_without_max_password_age_90_days_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_password_policy_max_age"]
}

trigger "query" "detect_and_correct_iam_account_password_policies_without_max_password_age_90_days" {
  title         = "Detect & correct IAM account password policies without maximum password age of 90 days"
  description   = "Detects IAM account password policies without maximum password age of 90 days and then updates to maximum password age of 90 days."

  enabled  = var.iam_account_password_policies_without_max_password_age_90_days_trigger_enabled
  schedule = var.iam_account_password_policies_without_max_password_age_90_days_trigger_schedule
  database = var.database
  sql      = local.iam_account_password_policies_without_max_password_age_90_days_query

  capture "insert" {
    pipeline = pipeline.correct_iam_account_password_policies_without_max_password_age_90_days
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_account_password_policies_without_max_password_age_90_days
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_account_password_policies_without_max_password_age_90_days" {
  title         = "Detect & correct IAM account password policies without maximum password age of 90 days"
  description   = "Detects IAM account password policies without maximum password age of 90 days and then updates to maximum password age of 90 days."

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
    default     = var.iam_account_password_policies_without_max_password_age_90_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_max_password_age_90_days_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_account_password_policies_without_max_password_age_90_days_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_account_password_policies_without_max_password_age_90_days
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

pipeline "correct_iam_account_password_policies_without_max_password_age_90_days" {
  title         = "Correct IAM account password policies without maximum password age of 90 days"
  description   = "Update password policy to maximum password age of 90 days for IAM accounts without maximum password age of 90 days."

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
    default     = var.iam_account_password_policies_without_max_password_age_90_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_max_password_age_90_days_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM account password policies with no maximum password age of 90 days."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.account_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_without_max_password_age_90_days
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

pipeline "correct_one_iam_account_password_policy_without_max_password_age_90_days" {
  title         = "Correct IAM account password policy without maximum password age of 90 days"
  description   = "Update password policy to maximum password age of 90 days for a IAM account without maximum password age of 90 days."

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
    default     = var.iam_account_password_policies_without_max_password_age_90_days_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_max_password_age_90_days_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account password policy ${param.title} with no maximum password age set to 90 days."
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
            text     = "Skipped IAM account password policy for ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_password_policy_max_age" = {
          label        = "Update password policy maximum password age to 90 days"
          value        = "update_password_policy_max_age"
          style        = local.style_alert
          pipeline_ref = pipeline.update_iam_account_password_policy_max_password_age
          pipeline_args = {
            max_password_age = 90
            cred             = param.cred
          }
          success_msg = "Updated IAM account password policy for ${param.title} to enforce a maximum password age of 90 days."
          error_msg   = "Error updating IAM account password policy for ${param.title}."
        }
      }
    }
  }
}

pipeline "update_iam_account_password_policy_max_password_age" {
  title       = "Update IAM account password policy max password age"
  description = "Updates the account password policymax password age for the AWS account."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "max_password_age" {
    type        = number
    description = "The number of days that an user password is valid."
    optional    = true
  }

  step "query" "get_password_policy" {
    database = var.database
    sql = <<-EOQ
      select
        account_id,
        minimum_password_length,
        require_symbols,
        require_numbers,
        require_uppercase_characters,
        require_lowercase_characters,
        allow_users_to_change_password,
        max_password_age,
        coalesce(password_reuse_prevention, 0) as password_reuse_prevention
      from
        aws_iam_account_password_policy
      where
        _ctx ->> 'connection_name' = '${param.cred}';
    EOQ
  }

  step "pipeline" "update_iam_account_password_policy" {
    depends_on = [step.query.get_password_policy]
    pipeline   = aws.pipeline.update_iam_account_password_policy
    args = {
      allow_users_to_change_password = step.query.get_password_policy.rows[0].allow_users_to_change_password
      cred                           = param.cred
      max_password_age               = param.max_password_age
      minimum_password_length        = step.query.get_password_policy.rows[0].minimum_password_length
      password_reuse_prevention      = step.query.get_password_policy.rows[0].password_reuse_prevention
      require_lowercase_characters   = step.query.get_password_policy.rows[0].require_lowercase_characters
      require_numbers                = step.query.get_password_policy.rows[0].require_numbers
      require_symbols                = step.query.get_password_policy.rows[0].require_symbols
      require_uppercase_characters   = step.query.get_password_policy.rows[0].require_uppercase_characters
    }
  }

}