locals {
  iam_accounts_password_policy_without_one_uppercase_letter_query = <<-EOQ
    select
      account_id as title,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_account_password_policy
    where
      require_uppercase_characters = false
      or require_uppercase_characters is null
  EOQ
}

variable "iam_accounts_password_policy_without_one_uppercase_letter_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_accounts_password_policy_without_one_uppercase_letter_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_accounts_password_policy_without_one_uppercase_letter_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_accounts_password_policy_without_one_uppercase_letter_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_password_policy_require_uppercase"]
}

trigger "query" "detect_and_correct_iam_accounts_password_policy_without_one_uppercase_letter" {
  title         = "Detect & correct IAM accounts password policy without requirement for any uppercase letter"
  description   = "Detects IAM accounts password policy without requirement for any uppercase letter and then updates to at least one lowercase letter."

  enabled  = var.iam_accounts_password_policy_without_one_uppercase_letter_trigger_enabled
  schedule = var.iam_accounts_password_policy_without_one_uppercase_letter_trigger_schedule
  database = var.database
  sql      = local.iam_accounts_password_policy_without_one_uppercase_letter_query

  capture "insert" {
    pipeline = pipeline.correct_iam_accounts_password_policy_without_one_uppercase_letter
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_accounts_password_policy_without_one_uppercase_letter" {
  title         = "Detect & correct IAM accounts password policy without requirement for any uppercase letter"
  description   = "Detects IAM accounts password policy without requirement for any uppercase letter and then updates to at least one lowercase letter."

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
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_accounts_password_policy_without_one_uppercase_letter_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_accounts_password_policy_without_one_uppercase_letter
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

pipeline "correct_iam_accounts_password_policy_without_one_uppercase_letter" {
  title         = "Correct IAM accounts password policy without requirement for any uppercase letter"
  description   = "Update password policy to at least one lowercase letter for IAM accounts without requirement for any uppercase letter."

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
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM account(s) password policy with no requirement for at least one uppercase letter."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.account_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_accounts_password_policy_without_one_uppercase_letter
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

pipeline "correct_one_iam_accounts_password_policy_without_one_uppercase_letter" {
  title         = "Correct IAM account password policy without requirement for any uppercase letter"
  description   = "Update password policy to at least one lowercase letter for acIAM account without requirement for any uppercase letter."

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
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_accounts_password_policy_without_one_uppercase_letter_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account password policy with no requirement for at least one uppercase letter in ${param.title}."
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
            text     = "Skipped IAM account password policy for ${param.title} with no requirement for at least one uppercase letter."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_password_policy_require_uppercase" = {
          label        = "Update Password Policy Require Uppercase"
          value        = "update_password_policy_require_uppercase"
          style        = local.style_alert
          pipeline_ref = pipeline.update_iam_account_password_policy_uppercase_letter
          pipeline_args = {
            require_uppercase_characters = true
            cred                        = param.cred
          }
          success_msg = "Updated IAM account password policy for ${param.title} to require at least one uppercase letter."
          error_msg   = "Error updating IAM account password policy ${param.title}."
        }
      }
    }
  }
}

pipeline "update_iam_account_password_policy_uppercase_letter" {
  title       = "Update IAM Account password policy uppercase letter requirement"
  description = "Updates the account password policy uppercase letter requirement for the AWS account."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "require_uppercase_characters" {
    type        = bool
    description = "Specifies whether to require uppercase characters in the password."
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
        password_reuse_prevention
      from
        aws_iam_account_password_policy
      where
        _ctx ->> 'connection_name' = '${param.cred}'
    EOQ
  }

  step "container" "update_iam_account_password_policy" {
    depends_on = [step.query.get_password_policy]
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["iam", "update-account-password-policy"],
      ["--minimum-password-length", tostring(step.query.get_password_policy.rows[0].minimum_password_length)],
			step.query.get_password_policy.rows[0].require_symbols ? ["--require-symbols"] : ["--no-require-symbols"],
			step.query.get_password_policy.rows[0].require_numbers ? ["--require-numbers"] : ["--no-require-numbers"],
      step.query.get_password_policy.rows[0].require_lowercase_characters ? ["--require-lowercase-characters"] : ["--no-require-lowercase-characters"],
      ["--require-uppercase-characters"],
			step.query.get_password_policy.rows[0].allow_users_to_change_password ? ["--allow-users-to-change-password"] : ["--no-allow-users-to-change-password"],
			step.query.get_password_policy.rows[0].max_password_age != null ? ["--max-password-age",  tostring(step.query.get_password_policy.rows[0].max_password_age)] : [],
			step.query.get_password_policy.rows[0].password_reuse_prevention != null ? ["--password-reuse-prevention",  tostring(step.query.get_password_policy.rows[0].password_reuse_prevention)] : []
    )

    env = credential.aws[param.cred].env
  }
}
