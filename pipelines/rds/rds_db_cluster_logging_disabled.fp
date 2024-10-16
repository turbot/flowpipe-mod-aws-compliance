locals {
  rds_db_cluster_if_logging_disabled_query = <<-EOQ
    select
      concat(db_cluster_identifier, ' [', account_id, '/', region, ']') as title,
      db_cluster_identifier,
      engine,
      region,
      sp_connection_name as conn
    from
      aws_rds_db_cluster
    where
      not enabled_cloudwatch_logs_exports is null;
  EOQ
}

variable "rds_db_cluster_if_logging_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_cluster_if_logging_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "rds_db_cluster_if_logging_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "rds_db_cluster_if_logging_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_db_cluster"]
}

trigger "query" "detect_and_correct_rds_db_cluster_if_logging_disabled" {
  title       = "Detect & correct RDS DB cluster if logging disabled"
  description = "Detects RDS DB clusters if logging is disabled and runs your chosen action."
  tags        = local.rds_common_tags

  enabled  = var.rds_db_cluster_if_logging_disabled_trigger_enabled
  schedule = var.rds_db_cluster_if_logging_disabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_cluster_if_logging_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_cluster_if_logging_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_cluster_if_logging_disabled" {
  title       = "Detect & correct RDS DB clusters if logging disabled"
  description = "Detects RDS DB clusters if logging is disabled and runs your chosen action."
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.rds_db_cluster_if_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_logging_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_cluster_if_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_cluster_if_logging_disabled
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

pipeline "correct_rds_db_cluster_if_logging_disabled" {
  title       = "Correct RDS DB cluster if logging disabled"
  description = "Runs corrective action on a collection of RDS DB clusters if logging is disabled."
  tags        = local.rds_common_tags

  param "items" {
    type = list(object({
      title                           = string
      db_cluster_identifier           = string
      enabled_cloudwatch_logs_exports = list(string)
      region                          = string
      engine                          = string
      conn                            = string
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
    default     = var.rds_db_cluster_if_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_logging_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} RDS DB clusters if logging is disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_cluster_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_cluster_if_logging_disabled
    args = {
      title                 = each.value.title
      db_cluster_identifier = each.value.db_cluster_identifier
      enable_logging        = true
      engine                = each.value.engine
      region                = each.value.region
      conn                  = connection.aws[each.value.conn]
      notifier              = param.notifier
      notification_level    = param.notification_level
      approvers             = param.approvers
      default_action        = param.default_action
      enabled_actions       = param.enabled_actions
    }
  }
}

pipeline "correct_one_rds_db_cluster_if_logging_disabled" {
  title       = "Correct one RDS DB cluster if logging is disabled"
  description = "Runs corrective action on an RDS DB cluster if logging is disabled."
  tags        = local.rds_common_tags

  param "title" {
    type        = string
    description = local.description_title
  }

  param "db_cluster_identifier" {
    type        = string
    description = "The identifier of the DB cluster."
  }

  param "engine" {
    type        = string
    description = "The engine of the DB cluster."
  }

  param "enable_logging" {
    type        = bool
    description = "Enables logging of a DB cluster."
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.rds_db_cluster_if_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_logging_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB cluster with logging disabled ${param.title}."
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
            text     = "Skipped RDS DB cluster ${param.title} with logging disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_db_cluster" = {
          label        = "Update DB Cluster"
          value        = "update_db_cluster"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.modify_rds_db_cluster
          pipeline_args = {
            db_cluster_identifier = param.db_cluster_identifier
            engine                = param.engine
            enable_logging        = true
            region                = param.region
            conn                  = param.conn
          }
          success_msg = "Updated RDS DB cluster ${param.title}."
          error_msg   = "Error updating RDS DB cluster ${param.title}."
        }
      }
    }
  }
}
