locals {
  dynamodb_tables_with_point_in_time_recovery_disabled_query = <<-EOQ
  select
    concat(name, ' [', region, '/', account_id, ']') as title,
    name,
    region,
    _ctx ->> 'connection_name' as cred
  from
    aws_dynamodb_table
  where
    lower(point_in_time_recovery_description ->> 'PointInTimeRecoveryStatus') = 'disabled';
  EOQ
}

variable "dynamodb_tables_with_point_in_time_recovery_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "dynamodb_tables_with_point_in_time_recovery_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "dynamodb_tables_with_point_in_time_recovery_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "dynamodb_table_dynamodb_tables_with_point_in_time_recovery_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_point_in_time_recovery"]
}

trigger "query" "detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled" {
  title         = "Detect & correct DynamoDB table with point-in-time recovery disabled"
  description   = "Detect DynamoDB tables with point-in-time recovery disabled and then skip or enable point-in-time recovery."
  // documentation = file("./dynamodb/docs/detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled_trigger.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused" })

  enabled  = var.dynamodb_tables_with_point_in_time_recovery_disabled_trigger_enabled
  schedule = var.dynamodb_tables_with_point_in_time_recovery_disabled_trigger_schedule
  database = var.database
  sql      = local.dynamodb_tables_with_point_in_time_recovery_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_dynamodb_tables_with_point_in_time_recovery_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled" {
  title         = "Detect & correct DynamoDB tables with point-in-time recovery disabled"
  description   = "Detect DynamoDB tables with point-in-time recovery disabled and then skip or enable point-in-time recovery."
  // documentation = file("./dynamodb/docs/detect_and_correct_dynamodb_tables_with_point_in_time_recovery_disabled.md")
  tags          = merge(local.dynamodb_common_tags, { class = "unused", type = "featured" })

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
    default     = var.dynamodb_tables_with_point_in_time_recovery_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_table_dynamodb_tables_with_point_in_time_recovery_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.dynamodb_tables_with_point_in_time_recovery_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_dynamodb_tables_with_point_in_time_recovery_disabled
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

pipeline "correct_dynamodb_tables_with_point_in_time_recovery_disabled" {
  title         = "Correct DynamoDB tables with point-in-time recovery disabled"
  description   = "Runs corrective action on a collection of DynamoDB tables with point-in-time recovery disabled."
  // documentation = file("./dynamodb/docs/correct_dynamodb_tables_with_point_in_time_recovery_disabled.md")
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
    default     = var.dynamodb_tables_with_point_in_time_recovery_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_table_dynamodb_tables_with_point_in_time_recovery_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} DynamoDB table(s) with point-in-time recovery disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_dynamodb_tables_with_point_in_time_recovery_disabled
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

pipeline "correct_one_dynamodb_tables_with_point_in_time_recovery_disabled" {
  title         = "Correct one DynamoDB table with point-in-time recovery disabled"
  description   = "Runs corrective action on a DynamoDB table with point-in-time recovery disabled."
  // documentation = file("./dynamodb/docs/correct_one_dynamodb_tables_with_point_in_time_recovery_disabled.md")
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
    default     = var.dynamodb_tables_with_point_in_time_recovery_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.dynamodb_table_dynamodb_tables_with_point_in_time_recovery_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected DynamoDB table ${param.title} with point-in-time recovery disabled."
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
            text     = "Skipped DynamoDB table ${param.title} with point-in-time recovery disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_point_in_time_recovery" = {
          label        = "Enable Point In Time Recovery"
          value        = "enable_point_in_time_recovery"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_update_dynamodb_continuous_backup
          pipeline_args = {
            table_name  = param.name
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Enabled point-in-time recovery for DynamoDB table ${param.title}."
          error_msg   = "Error enabling point-in-time recovery for DynamoDB table ${param.title}."
        }
      }
    }
  }
}
