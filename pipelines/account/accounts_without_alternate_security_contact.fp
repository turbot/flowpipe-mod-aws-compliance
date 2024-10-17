locals {
  accounts_without_alternate_security_contact_query = <<-EOQ
    with alternate_security_contact as (
      select
        count(name) as security_contact_count
      from
        aws_account_alternate_contact
      where
        contact_type = 'SECURITY'
    )
    select
      concat(a.title, ' [', a.account_id, ']') as title,
      a.sp_connection_name as conn
    from
      aws_account as a,
      alternate_security_contact as c
    where
      c.security_contact_count <= 0;
  EOQ
}

variable "accounts_without_alternate_security_contact_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "add_alternate_security_contact"]

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_email_address" {
  type        = string
  description = "The email address of the alternate contact."
  default     = ""

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_phone_number" {
  type        = string
  description = "The phone number of the alternate contact."
  default     = ""

  tags = {
    folder = "Advanced/Account"
  }
}

variable "accounts_without_alternate_security_contact_title" {
  type        = string
  description = "The title of the alternate contact."
  default     = ""
}

variable "accounts_without_alternate_security_contact_name" {
  type        = string
  description = "The name of the alternate contact."
  default     = ""
}

trigger "query" "detect_and_correct_accounts_without_alternate_security_contact" {
  title       = "Detect & correct accounts without alternate security contact"
  description = "Detect accounts without alternate security contact and then add alternate security contact."

  tags = local.account_common_tags

  enabled  = var.accounts_without_alternate_security_contact_trigger_enabled
  schedule = var.accounts_without_alternate_security_contact_trigger_schedule
  database = var.database
  sql      = local.accounts_without_alternate_security_contact_query

  capture "insert" {
    pipeline = pipeline.correct_accounts_without_alternate_security_contact
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_accounts_without_alternate_security_contact" {
  title       = "Detect & correct accounts without alternate security contact"
  description = "Detect accounts without alternate security contact and then add alternate security contact."

  tags = local.account_common_tags

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
    default     = var.accounts_without_alternate_security_contact_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.accounts_without_alternate_security_contact_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.accounts_without_alternate_security_contact_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_accounts_without_alternate_security_contact
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

pipeline "correct_accounts_without_alternate_security_contact" {
  title       = "Correct accounts without alternate security contact"
  description = "Add alternate security contact for accounts without alternate security contact."

  tags = merge(local.account_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title = string
      conn  = string
    }))
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
    default     = var.accounts_without_alternate_security_contact_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.accounts_without_alternate_security_contact_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected account(s) ${length(param.items)} without alternate security contact."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_account_without_alternate_security_contact
    args = {
      title              = each.value.title
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_account_without_alternate_security_contact" {
  title       = "Correct one account without alternate security contact"
  description = "Add alternate security contact for an account."

  tags = merge(local.account_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "alternate_account_title" {
    type        = string
    description = "The title of the alternate contact"
    default     = var.accounts_without_alternate_security_contact_title
  }

  param "name" {
    type        = string
    description = "The name of the alternate contact"
    default     = var.accounts_without_alternate_security_contact_name
  }

  param "email_address" {
    type        = string
    description = "The email address of the alternate contact."
    default     = var.accounts_without_alternate_security_contact_email_address
  }

  param "phone_number" {
    type        = string
    description = "The phone number of the alternate contact."
    default     = var.accounts_without_alternate_security_contact_phone_number
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
    default     = var.accounts_without_alternate_security_contact_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.accounts_without_alternate_security_contact_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected account ${param.title} without an alternate security contact."
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
            send     = param.notification_level == local.level_info
            text     = "Skipped account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "add_alternate_security_contact" = {
          label        = "Add alternate security contact"
          value        = "add_alternate_security_contact"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.put_alternate_contact
          pipeline_args = {
            name                   = param.name
            conn                   = param.conn
            alternate_contact_type = "SECURITY"
            email_address          = param.email_address
            phone_number           = param.phone_number
            title                  = param.alternate_account_title
          }
          success_msg = "Added alternate security contact ${param.name} for account ${param.title}."
          error_msg   = "Error adding alternate security contact ${param.name} for account ${param.title}."
        }
      }
    }
  }
}
