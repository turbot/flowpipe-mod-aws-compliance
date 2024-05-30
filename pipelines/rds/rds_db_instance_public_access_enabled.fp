locals {
  rds_db_instance_if_public_access_enabled_query = <<-EOQ
    select
      concat(db_instance_identifier, ' [', region, '/', account_id, ']') as title,
      db_instance_identifier,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_rds_db_instance
    where
      publicly_accessible;
  EOQ
}

trigger "query" "detect_and_correct_rds_db_instance_if_public_access_enabled" {
  title         = "Detect & correct RDS DB instance if public access enabled"
  description   = "Detects RDS DB instances if public access is enabled and runs your chosen action."
  // // documentation = file("./rds/docs/detect_and_correct_rds_db_instance_if_public_access_enabled_trigger.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  enabled  = var.rds_db_instance_if_public_access_enabled_trigger_enabled
  schedule = var.rds_db_instance_if_public_access_enabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_instance_if_public_access_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instance_if_public_access_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instance_if_public_access_enabled" {
  title         = "Detect & correct RDS DB instances if public access enabled"
  description   = "Detects RDS DB instances if public access is enabled and runs your chosen action."
  // // documentation = file("./rds/docs/detect_and_correct_rds_db_instance_if_public_access_enabled.md")
  tags          = merge(local.rds_common_tags, { class = "unused", type = "featured" })

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
    default     = var.rds_db_instance_if_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_public_access_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instance_if_public_access_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instance_if_public_access_enabled
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

pipeline "correct_rds_db_instance_if_public_access_enabled" {
  title         = "Correct RDS DB instance if public access enabled"
  description   = "Runs corrective action on a collection of RDS DB instances if public access is enabled."
  // // documentation = file("./rds/docs/correct_rds_db_instance_if_public_access_enabled.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title                  = string
      db_instance_identifier = string
      publicly_accessible    = bool
      region                 = string
      cred                   = string
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
    default     = var.rds_db_instance_if_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_public_access_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} RDS DB instances with public access enabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_instance_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_if_public_access_enabled
    args = {
      title                  = each.value.title
      db_instance_identifier = each.value.db_instance_identifier
      publicly_accessible    = false
      region                 = each.value.region
      cred                   = each.value.cred
      notifier               = param.notifier
      notification_level     = param.notification_level
      approvers              = param.approvers
      default_action         = param.default_action
      enabled_actions        = param.enabled_actions
    }
  }
}

pipeline "correct_one_rds_db_instance_if_public_access_enabled" {
  title         = "Correct one RDS DB instance if public access enabled"
  description   = "Runs corrective action on an RDS DB instance if public access is enabled."
  // // documentation = file("./rds/docs/correct_one_rds_db_instance_if_public_access_enabled.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "db_instance_identifier" {
    type        = string
    description = "The identifier of the DB instance."
  }

  param "publicly_accessible" {
    type        = bool
    description = "Enables or disables public access for a DB instance."
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
    default     = var.rds_db_instance_if_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_public_access_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB instance with public access enabled ${param.title}."
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
            text     = "Skipped RDS DB instance ${param.title} with public access enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_db_instance" = {
          label        = "Update DB Instance"
          value        = "update_db_instance"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_rds_db_instance
          pipeline_args = {
            db_instance_identifier = param.db_instance_identifier
            publicly_accessible    = false
            region                 = param.region
            cred                   = param.cred
          }
          success_msg = "Updated RDS DB instance ${param.title}."
          error_msg   = "Error updating RDS DB instance ${param.title}."
        }
      }
    }
  }
}

variable "rds_db_instance_if_public_access_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_instance_if_public_access_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "rds_db_instance_if_public_access_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "rds_db_instance_if_public_access_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_db_instance"]
}