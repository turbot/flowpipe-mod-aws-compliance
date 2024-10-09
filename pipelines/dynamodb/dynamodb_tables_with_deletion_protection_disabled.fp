locals {
  dynamodb_tables_with_deletion_protection_disabled_query = <<-EOQ
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    _ctx ->> 'connection_name' as cred
  from
    aws_dynamodb_table
  where
    not deletion_protection_enabled;
  EOQ
}

trigger "query" "detect_and_correct_dynamodb_tables_with_deletion_protection_disabled" {
  title         = "Detect & correct DynamoDB table with deletion protection disabled"
  description   = "Detect DynamoDB tables with deletion protection disabled and then skip or enable deletion protection."
  // documentation = file("./dynamodb/docs/detect_and_correct_dynamodb_tables_with_deletion_protection_disabled_trigger.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused" })

  enabled  = var.dynamodb_tables_with_deletion_protection_disabled_trigger_enabled
  schedule = var.dynamodb_tables_with_deletion_protection_disabled_trigger_schedule
  database = var.database
  sql      = local.dynamodb_tables_with_deletion_protection_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_dynamodb_tables_with_deletion_protection_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

variable "dynamodb_tables_with_deletion_protection_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "dynamodb_tables_with_deletion_protection_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "dynamodb_tables_with_deletion_protection_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "dynamodb_tables_with_deletion_protection_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_deletion_protection"]
}

pipeline "detect_and_correct_dynamodb_tables_with_deletion_protection_disabled" {
  title         = "Detect & correct DynamoDB tables with deletion protection disabled"
  description   = "Detect DynamoDB tables with deletion protection disabled and then skip or enable deletion protection."
  // documentation = file("./dynamodb/docs/detect_and_correct_dynamodb_tables_with_deletion_protection_disabled.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused", type = "recommended" })

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
    default     = var.dynamodb_tables_with_deletion_protection_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_tables_with_deletion_protection_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.dynamodb_tables_with_deletion_protection_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_dynamodb_tables_with_deletion_protection_disabled
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

pipeline "correct_dynamodb_tables_with_deletion_protection_disabled" {
  title         = "Correct DynamoDB tables with deletion protection disabled"
  description   = "Runs corrective action on a collection of DynamoDB tables with deletion protection disabled."
  // documentation = file("./dynamodb/docs/correct_dynamodb_tables_with_deletion_protection_disabled.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title       = string
      name        = string
      region      = string
      cred        = string
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
    default     = var.dynamodb_tables_with_deletion_protection_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_tables_with_deletion_protection_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} DynamoDB table(s) with deletion protection disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : items.name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_dynamodb_table_with_deletion_protection_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_dynamodb_table_with_deletion_protection_disabled" {
  title         = "Correct one DynamoDB table with deletion protection disabled"
  description   = "Runs corrective action on an DynamoDB table with deletion protection disabled."
  // documentation = file("./dynamodb/docs/correct_one_dynamodb_table_with_deletion_protection_disabled.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the DynamoDB table."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    default     = var.dynamodb_tables_with_deletion_protection_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_tables_with_deletion_protection_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected DynamoDB table ${param.title} with deletion protection disabled."
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
            text     = "Skipped DynamoDB table ${param.title} with deletion protection disabled."
          }
          success_msg = "Skipped DynamoDB table ${param.title} with deletion protection disabled."
          error_msg   = ""
        },
        "enable_deletion_protection" = {
          label        = "Enable Deletion Protection"
          value        = "enable_deletion_protection"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.update_dynamodb_table
          pipeline_args = {
            table_name  = param.name
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Enabled deletion protection for DynamoDB table ${param.title}."
          error_msg   = "Error enabling deletion protection for DynamoDB table ${param.title}."
        }
      }
    }
  }
}
