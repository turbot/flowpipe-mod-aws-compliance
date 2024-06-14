locals {
  neptune_db_cluster_audit_logs_query = <<-EOQ
  select
    concat(db_cluster_identifier, ' [', region, '/', account_id, ']') as title,
    db_cluster_identifier,
    region,
    _ctx ->> 'connection_name' as cred
  from
    aws_neptune_db_cluster
  where
    not enabled_cloudwatch_logs_exports @> '["audit"]' or enabled_cloudwatch_logs_exports is null;
  EOQ
}

trigger "query" "detect_and_correct_neptune_db_cluster_if_audit_logs_disabled" {
  title       = "Detect & Correct Neptune DB Cluster if Audit Logs Disabled"
  description = "Detects Neptune DB clusters if audit logs are disabled and runs your chosen action."
  // tags        = merge(local.neptune_common_tags, { class = "unused" })

  enabled  = var.neptune_db_cluster_if_audit_logs_disabled_trigger_enabled
  schedule = var.neptune_db_cluster_if_audit_logs_disabled_trigger_schedule
  database = var.database
  sql      = local.neptune_db_cluster_audit_logs_query

  capture "insert" {
    pipeline = pipeline.correct_neptune_db_cluster_if_audit_logs_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_neptune_db_cluster_if_audit_logs_disabled" {
  title       = "Detect & Correct Neptune DB Clusters if Audit Logs Disabled"
  description = "Detects Neptune DB clusters if audit logs are disabled and runs your chosen action."
  // tags        = merge(local.neptune_common_tags, { class = "unused", type = "featured" })

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
    default     = var.neptune_db_cluster_if_audit_logs_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.neptune_db_cluster_if_audit_logs_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.neptune_db_cluster_audit_logs_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_neptune_db_cluster_if_audit_logs_disabled
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

pipeline "correct_neptune_db_cluster_if_audit_logs_disabled" {
  title       = "Correct Neptune DB Cluster if Audit Logs Disabled"
  description = "Runs corrective action on a collection of Neptune DB clusters if audit logs are disabled."
  // tags        = merge(local.neptune_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title                 = string
      db_cluster_identifier = string
      region                = string
      cred                  = string
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
    default     = var.neptune_db_cluster_if_audit_logs_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.neptune_db_cluster_if_audit_logs_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Neptune DB clusters with audit logs disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_cluster_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_neptune_db_cluster_if_audit_logs_disabled
    args = {
      db_cluster_identifier = each.value.db_cluster_identifier
      region                = each.value.region
      cred                  = each.value.cred
      notifier              = param.notifier
      notification_level    = param.notification_level
      approvers             = param.approvers
      default_action        = param.default_action
      enabled_actions       = param.enabled_actions
    }
  }
}

pipeline "correct_one_neptune_db_cluster_if_audit_logs_disabled" {
  title       = "Correct One Neptune DB Cluster if Audit Logs Disabled"
  description = "Runs corrective action on a Neptune DB cluster if audit logs are disabled."
  // tags        = merge(local.neptune_common_tags, { class = "unused" })

  param "db_cluster_identifier" {
    type        = string
    description = "The identifier of the Neptune DB cluster."
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
    default     = var.neptune_db_cluster_if_audit_logs_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.neptune_db_cluster_if_audit_logs_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Neptune DB cluster with audit logs disabled ${param.db_cluster_identifier}."
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
            text     = "Skipped Neptune DB cluster ${param.db_cluster_identifier} with audit logs disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_audit_logs" = {
          label        = "Enable Audit Logs"
          value        = "enable_audit_logs"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_neptune_db_cluster
          pipeline_args = {
            db_cluster_identifier       = param.db_cluster_identifier
            region                      = param.region
            cred                        = param.cred
            enable_cloudwatch_log_types = ["audit"]
          }
          success_msg = "Enabled audit logs for Neptune DB cluster ${param.db_cluster_identifier}."
          error_msg   = "Error enabling audit logs for Neptune DB cluster ${param.db_cluster_identifier}."
        }
      }
    }
  }
}

variable "neptune_db_cluster_if_audit_logs_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "neptune_db_cluster_if_audit_logs_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "neptune_db_cluster_if_audit_logs_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "enable_audit_logs"
}

variable "neptune_db_cluster_if_audit_logs_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_audit_logs"]
}
