locals {
  rds_db_instance_with_public_access_enabled_query = <<-EOQ
    select
      concat(db_instance_identifier, ' [', account_id, '/', region, ']') as title,
      db_instance_identifier,
      region,
      sp_connection_name as conn
    from
      aws_rds_db_instance
    where
      publicly_accessible;
  EOQ

  rds_db_instances_with_public_access_enabled_default_action_enum  = ["notify", "skip", "disable_public_access"]
  rds_db_instances_with_public_access_enabled_enabled_actions_enum = ["skip", "disable_public_access"]
}

variable "rds_db_instances_with_public_access_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_public_access_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_public_access_enabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "disable_public_access"]

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_public_access_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "disable_public_access"]
  enum        = ["skip", "disable_public_access"]

  tags = {
    folder = "Advanced/RDS"
  }
}

trigger "query" "detect_and_correct_rds_db_instances_with_public_access_enabled" {
  title       = "Detect & correct RDS DB instances with public access enabled"
  description = "Detect RDS DB instances with public access enabled and then skip or disable public access."
  tags        = local.rds_common_tags

  enabled  = var.rds_db_instances_with_public_access_enabled_trigger_enabled
  schedule = var.rds_db_instances_with_public_access_enabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_instance_with_public_access_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instances_with_public_access_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instances_with_public_access_enabled" {
  title       = "Detect & correct RDS DB instances with public access enabled"
  description = "Detect RDS DB instances with public access enabled and then skip or disable public access."
  tags        = merge(local.rds_common_tags, { recommended = "true" })

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
    default     = var.rds_db_instances_with_public_access_enabled_default_action
    enum        = local.rds_db_instances_with_public_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_public_access_enabled_enabled_actions
    enum        = local.rds_db_instances_with_public_access_enabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instance_with_public_access_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instances_with_public_access_enabled
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

pipeline "correct_rds_db_instances_with_public_access_enabled" {
  title       = "Correct RDS DB instances with public access enabled"
  description = "Disable public access on a collection of RDS DB instances with public access enabled."
  tags        = merge(local.rds_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                  = string
      db_instance_identifier = string
      publicly_accessible    = bool
      region                 = string
      conn                   = string
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
    default     = var.rds_db_instances_with_public_access_enabled_default_action
    enum        = local.rds_db_instances_with_public_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_public_access_enabled_enabled_actions
    enum        = local.rds_db_instances_with_public_access_enabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} RDS DB instance(s) with public access enabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.db_instance_identifier => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_with_public_access_enabled
    args = {
      title                  = each.value.title
      db_instance_identifier = each.value.db_instance_identifier
      publicly_accessible    = false
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      notifier               = param.notifier
      notification_level     = param.notification_level
      approvers              = param.approvers
      default_action         = param.default_action
      enabled_actions        = param.enabled_actions
    }
  }
}

pipeline "correct_one_rds_db_instance_with_public_access_enabled" {
  title       = "Correct one RDS DB instance with public access enabled"
  description = "Disable public access on an RDS DB instance with public access enabled."
  tags        = merge(local.rds_common_tags, { folder = "Internal" })

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
    default     = var.rds_db_instances_with_public_access_enabled_default_action
    enum        = local.rds_db_instances_with_public_access_enabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_public_access_enabled_enabled_actions
    enum        = local.rds_db_instances_with_public_access_enabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB instance ${param.title} with public access enabled."
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
            text     = "Skipped RDS DB instance ${param.title} with public access enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "disable_public_access" = {
          label        = "Disable public access for RDS DB instance"
          value        = "disable_public_access"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.modify_rds_db_instance
          pipeline_args = {
            db_instance_identifier = param.db_instance_identifier
            publicly_accessible    = false
            region                 = param.region
            conn                   = param.conn
          }
          success_msg = "Disabled public access for RDS DB instance ${param.title}."
          error_msg   = "Error disabling public access for RDS DB instance ${param.title}."
        }
      }
    }
  }
}
