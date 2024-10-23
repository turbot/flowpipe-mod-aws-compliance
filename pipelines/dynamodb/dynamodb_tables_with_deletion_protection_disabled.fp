locals {
  dynamodb_tables_with_deletion_protection_disabled_query = <<-EOQ
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    sp_connection_name as conn
  from
    aws_dynamodb_table
  where
    not deletion_protection_enabled;
  EOQ

  dynamodb_tables_with_deletion_protection_disabled_default_action_enum  = ["notify", "skip", "enable_deletion_protection"]
  dynamodb_tables_with_deletion_protection_disabled_enabled_actions_enum = ["skip", "enable_deletion_protection"]
}

trigger "query" "detect_and_correct_dynamodb_tables_with_deletion_protection_disabled" {
  title       = "Detect & correct DynamoDB table with deletion protection disabled"
  description = "Detect DynamoDB tables with deletion protection disabled and then skip or enable deletion protection."

  tags = local.dynamodb_common_tags

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

  tags = {
    folder = "Advanced/DynamoDB"
  }
}

variable "dynamodb_tables_with_deletion_protection_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/DynamoDB"
  }
}

variable "dynamodb_tables_with_deletion_protection_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "enable_deletion_protection"]

  tags = {
    folder = "Advanced/DynamoDB"
  }
}

variable "dynamodb_tables_with_deletion_protection_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_deletion_protection"]
  enum        = ["skip", "enable_deletion_protection"]

  tags = {
    folder = "Advanced/DynamoDB"
  }
}

pipeline "detect_and_correct_dynamodb_tables_with_deletion_protection_disabled" {
  title       = "Detect & correct DynamoDB tables with deletion protection disabled"
  description = "Detect DynamoDB tables with deletion protection disabled and then skip or enable deletion protection."

  tags = merge(local.dynamodb_common_tags, { recommended = "true" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
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
  title       = "Correct DynamoDB tables with deletion protection disabled"
  description = "Runs corrective action on a collection of DynamoDB tables with deletion protection disabled."

  tags = merge(local.dynamodb_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title  = string
      name   = string
      region = string
      conn   = string
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.dynamodb_tables_with_deletion_protection_disabled_default_action
    enum        = local.dynamodb_tables_with_deletion_protection_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_tables_with_deletion_protection_disabled_enabled_actions
    enum        = local.dynamodb_tables_with_deletion_protection_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
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
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_dynamodb_table_with_deletion_protection_disabled" {
  title       = "Correct one DynamoDB table with deletion protection disabled"
  description = "Runs corrective action on an DynamoDB table with deletion protection disabled."

  tags = merge(local.dynamodb_common_tags, { folder = "Internal" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
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
          success_msg = ""
          error_msg   = ""
        },
        "enable_deletion_protection" = {
          label        = "Enable Deletion Protection"
          value        = "enable_deletion_protection"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.update_dynamodb_table
          pipeline_args = {
            table_name = param.name
            region     = param.region
            conn       = param.conn
          }
          success_msg = "Enabled deletion protection for DynamoDB table ${param.title}."
          error_msg   = "Error enabling deletion protection for DynamoDB table ${param.title}."
        }
      }
    }
  }
}
