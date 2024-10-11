locals {
  iam_account_password_policies_without_password_reuse_24_query = <<-EOQ
    select
      a.account_id as title,
      a.account_id,
      a.sp_connection_name as conn
    from
      aws_account as a
      left join aws_iam_account_password_policy as pol on a.account_id = pol.account_id
    where
      password_reuse_prevention < 24
      or password_reuse_prevention is null;
  EOQ
}

variable "iam_account_password_policies_without_password_reuse_24_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_password_policies_without_password_reuse_24_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_password_policies_without_password_reuse_24_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_password_policies_without_password_reuse_24_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_password_policy_reuse_prevention"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_account_password_policies_without_password_reuse_24" {
  title         = "Detect & correct IAM account password policies without password reuse 24"
  description   = "Detects IAM account password policies that do not enforce a password reuse prevention policy of 24 and updates them."
  tags          = local.iam_common_tags

  enabled  = var.iam_account_password_policies_without_password_reuse_24_trigger_enabled
  schedule = var.iam_account_password_policies_without_password_reuse_24_trigger_schedule
  database = var.database
  sql      = local.iam_account_password_policies_without_password_reuse_24_query

  capture "insert" {
    pipeline = pipeline.correct_iam_account_password_policies_without_password_reuse_24
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_account_password_policies_without_password_reuse_24" {
  title         = "Detect & correct IAM account password policies without password reuse 24"
  description   = "Detects IAM account password policies that do not enforce a password reuse prevention policy of 24 and updates them."
  tags          = local.iam_common_tags

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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_password_policies_without_password_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_password_reuse_24_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_account_password_policies_without_password_reuse_24_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_account_password_policies_without_password_reuse_24
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

pipeline "correct_iam_account_password_policies_without_password_reuse_24" {
  title         = "Correct IAM account password policies without password reuse 24"
  description   = "Runs corrective action on a collection of IAM account password policies that do not enforce a password reuse prevention policy of 24."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title          = string
      account_id     = string
      conn           = string
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_password_policies_without_password_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_password_reuse_24_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM account password policies with no password reuse prevention policy of 24."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.account_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_without_password_reuse_24
    args = {
      title              = each.value.title
      account_id         = each.value.account_id
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_account_password_policy_without_password_reuse_24" {
  title         = "Correct one IAM account password policy without password reuse 24"
  description   = "Runs corrective action for an IAM account password policy that do not enforce a password reuse prevention policy of 24."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_password_policies_without_password_reuse_24_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_password_policies_without_password_reuse_24_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account ${param.title} password policy with no password reuse prevention policy of 24."
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
          pipeline_ref = pipeline.update_iam_account_password_policy_password_reuse
          pipeline_args = {
            password_reuse_prevention = 24
            conn                     = param.conn
          }
          success_msg = "Updated IAM account password policy for ${param.title} to enforce a password reuse prevention policy of 24."
          error_msg   = "Error updating IAM account password policy ${param.title}."
        }
      }
    }
  }
}

pipeline "update_iam_account_password_policy_password_reuse" {
  title       = "Update IAM account password policy password reuse"
  description = "Updates the account password policy password reuse for the AWS account."

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "password_reuse_prevention" {
    type        = number
    description = "Prevents the reuse of the specified number of previous passwords."
  }

  step "query" "get_password_policy" {
    database = var.database
    sql = <<-EOQ
      select
        a.account_id,
        coalesce(minimum_password_length, 8) as minimum_password_length,
        coalesce(require_symbols, false) as require_symbols,
        coalesce(require_numbers, false) as require_numbers,
        coalesce(require_uppercase_characters, false) as require_uppercase_characters,
        coalesce(require_lowercase_characters, false) as require_lowercase_characters,
        coalesce(allow_users_to_change_password, false) as allow_users_to_change_password,
        coalesce(max_password_age, 0) as max_password_age,
        coalesce(password_reuse_prevention, 0) as password_reuse_prevention
      from
        aws_account as a
        left join aws_iam_account_password_policy as pol on a.account_id = pol.account_id
      where
        a.sp_connection_name = ${param.conn}; -- TODO: Re-test this after param.conn change
    EOQ
  }

  step "pipeline" "update_iam_account_password_policy" {
    depends_on = [step.query.get_password_policy]
    pipeline   = aws.pipeline.update_iam_account_password_policy
    args = {
      allow_users_to_change_password = step.query.get_password_policy.rows[0].allow_users_to_change_password
      conn                           = param.conn
      max_password_age               = step.query.get_password_policy.rows[0].max_password_age
      minimum_password_length        = step.query.get_password_policy.rows[0].minimum_password_length
      password_reuse_prevention      = param.password_reuse_prevention
      require_lowercase_characters   = step.query.get_password_policy.rows[0].require_lowercase_characters
      require_numbers                = step.query.get_password_policy.rows[0].require_numbers
      require_symbols                = step.query.get_password_policy.rows[0].require_symbols
      require_uppercase_characters   = step.query.get_password_policy.rows[0].require_uppercase_characters
    }
  }
}
