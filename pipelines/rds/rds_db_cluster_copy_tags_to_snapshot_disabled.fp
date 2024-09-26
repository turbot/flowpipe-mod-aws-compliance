locals {
  rds_db_cluster_if_copy_tags_to_snapshot_disabled_query = <<-EOQ
    select
      concat(db_cluster_identifier, ' [', account_id, '/', region, ']') as title,
      db_cluster_identifier,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_rds_db_cluster
    where
      (not copy_tags_to_snapshot);
  EOQ
}

trigger "query" "detect_and_correct_rds_db_cluster_if_copy_tags_to_snapshot_disabled" {
  title         = "Detect & correct RDS DB cluster if copy tags to snapshot disabled"
  description   = "Detects RDS DB clusters if copy tags to snapshot disabled and runs your chosen action."
  tags          = merge(local.rds_common_tags, { class = "unused" })

  enabled  = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_trigger_enabled
  schedule = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_cluster_if_copy_tags_to_snapshot_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_cluster_if_copy_tags_to_snapshot_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_cluster_if_copy_tags_to_snapshot_disabled" {
  title         = "Detect & correct RDS DB clusters if copy tags to snapshot disabled"
  description   = "Detects RDS DB clusters if copy tags to snapshot disabled and runs your chosen action."
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
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_cluster_if_copy_tags_to_snapshot_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_cluster_if_copy_tags_to_snapshot_disabled
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

pipeline "correct_rds_db_cluster_if_copy_tags_to_snapshot_disabled" {
  title         = "Correct RDS DB cluster if copy tags to snapshot disabled"
  description   = "Runs corrective action on a collection of RDS DB clusters if copy tags to snapshot disabled."
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title                  = string
      db_cluster_identifier = string
      copy_tags_to_snapshot    = bool
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
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} RDS DB clusters if copy tags to snapshot disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_cluster_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_cluster_if_copy_tags_to_snapshot_disabled
    args = {
      title                  = each.value.title
      db_cluster_identifier = each.value.db_cluster_identifier
      copy_tags_to_snapshot    = true
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

pipeline "correct_one_rds_db_cluster_if_copy_tags_to_snapshot_disabled" {
  title         = "Correct one RDS DB cluster if copy tags to snapshot disabled"
  description   = "Runs corrective action on an RDS DB cluster if copy tags to snapshot disabled."
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "db_cluster_identifier" {
    type        = string
    description = "The identifier of the DB cluster."
  }

  param "copy_tags_to_snapshot" {
    type        = bool
    description = "Enables the copy tags to snapshot property of a DB cluster"
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
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_cluster_if_copy_tags_to_snapshot_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB cluster with copy tags to snapshot disabled ${param.title}."
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
            text     = "Skipped RDS DB cluster ${param.title} with copy tags to snapshot disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_db_cluster" = {
          label        = "Update DB Cluster"
          value        = "update_db_cluster"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_rds_db_cluster
          pipeline_args = {
            db_cluster_identifier = param.db_cluster_identifier
            copy_tags_to_snapshot = true
            region                 = param.region
            cred                   = param.cred
          }
          success_msg = "Updated RDS DB cluster ${param.title}."
          error_msg   = "Error updating RDS DB cluster ${param.title}."
        }
      }
    }
  }
}

variable "rds_db_cluster_if_copy_tags_to_snapshot_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_cluster_if_copy_tags_to_snapshot_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "rds_db_cluster_if_copy_tags_to_snapshot_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "rds_db_cluster_if_copy_tags_to_snapshot_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_db_cluster"]
}
