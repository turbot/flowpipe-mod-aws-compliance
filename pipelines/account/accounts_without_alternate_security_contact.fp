locals {
  accounts_without_alternate_security_contact_query = <<-EOQ
  with alternate_security_contact as (
    select
      name,
      account_id
    from
      aws_account_alternate_contact
    where
      contact_type = 'SECURITY'
  ),
  account as (
    select
      arn,
      partition,
      title,
      account_id,
      _ctx
    from
      aws_account
  )
  select
    concat(a.title, ' [', a.account_id, ']') as title,
    a.account_id,
    arn
  from
    account as a,
    alternate_security_contact as c
  where
    c.account_id = a.account_id
    and c.name is null;
  EOQ
}

variable "accounts_without_alternate_security_contact_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "accounts_without_alternate_security_contact_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "accounts_without_alternate_security_contact_default_action" {
  type        = string
  description = "The default action to use for detected items."
  default     = "notify"
}

variable "accounts_without_alternate_security_contact_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "add_alternate_contact"]
}

variable "alternate_contact_type" {
  type        = string
  description = "The alternate contact type."
  default     = "SECURITY"
}

variable "email_address" {
  type        = string
  description = "The email address of the alternate contact."
  default     = "" // TODO: fix this
}

variable "phone_number" {
  type        = string
  description = "The phone number of the alternate contact."
  default     = "" // TODO: fix this
}

variable "alternate_account_title" {
  type        = string
  description = "The title of the alternate contact."
  default     = "" // TODO: fix this
}

variable "alternate_account_name" {
  type        = string
  description = "The name of the alternate contact."
  default     = "" // TODO: fix this
}

trigger "query" "detect_and_correct_accounts_without_alternate_security_contact" {
  title       = "Detect & Correct Accounts Without Alternate Security Contact"
  description = "Detect accounts without alternate security contact and then registers an alternate security contact."
  // // documentation = file("./account/docs/detect_and_correct_accounts_without_alternate_security_contact_trigger.md")
  // tags          = merge(local.account_common_tags, { class = "unused" })

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
  title       = "Detect & Correct Accounts Alternate Security Contact"
  description = "Detect accounts with alternate security contact and then registers alternate security contact."
  // // documentation = file("./account/docs/detect_and_correct_accounts_without_alternate_security_contact.md")
  // tags          = merge(local.account_common_tags, { class = "unused", type = "featured" })

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

  output "row_data" {
    description = "Row data"
    value       = length(step.query.detect.rows)
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
  title       = "Correct Accounts Alternate Security Contact"
  description = "Registers alternate security contact for accounts with alternate security contact."
  // // documentation = file("./account/docs/correct_accounts_without_alternate_security_contact.md")
  // tags          = merge(local.account_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      account_id = string
      title      = string
      cred       = string
    }))
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
    default     = var.accounts_without_alternate_security_contact_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.accounts_without_alternate_security_contact_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "info"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} account(s) without alternate security contact."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_account_without_alternate_security_contact
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

pipeline "correct_one_account_without_alternate_security_contact" {
  title       = "Correct Account Without Alternate Security Contact"
  description = "Registers alternate security contact for account with alternate security contact."
  // // documentation = file("./account/docs/correct_one_account_without_alternate_security_contact.md")
  // tags          = merge(local.account_common_tags, { class = "unused" })

  param "alternate_account_title" {
    type        = string
    description = "The title of the alternate contact"
    default     = var.alternate_account_title
  }

  param "alternate_account_name" {
    type        = string
    description = "The name of the alternate contact"
    default     = var.alternate_account_name
  }

  param "alternate_contact_type" {
    type        = string
    description = "The alternate contact type."
    default     = var.alternate_contact_type
  }

  param "email_address" {
    type        = string
    description = "The email address of the alternate contact."
    default     = var.email_address
  }

  param "phone_number" {
    type        = string
    description = "The phone number of the alternate contact."
    default     = var.phone_number
  }

  param "account_id" {
    type        = string
    description = "The account ID."
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
      detect_msg         = "Detected account ${param.title} without alternate security contact."
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
            send     = param.notification_level == "verbose"
            text     = "Skipped account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "add_alternate_contact" = {
          label        = "Register alternate security contact"
          value        = "add_alternate_contact"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.put_alternate_contact
          pipeline_args = {
            name                   = param.alternate_account_name
            cred                   = param.cred
            account_id             = param.account_id
            alternate_contact_type = "SECURITY"
            email_address          = param.email_address
            phone_number           = param.phone_number
            title                  = param.alternate_account_title
          }
          success_msg = "Registered alternate security contact for account ${param.title}."
          error_msg   = "Error registering alternate security contact for account ${param.title}."
        }
      }
    }
  }
}

