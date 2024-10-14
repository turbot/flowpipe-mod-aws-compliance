locals {
  rds_db_instances_with_auto_minor_version_upgrade_disabled_query = <<-EOQ
    select
      concat(db_instance_identifier, ' [', account_id, '/', region, ']') as title,
      db_instance_identifier,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_rds_db_instance
    where
      not auto_minor_version_upgrade;
  EOQ
}

variable "rds_db_instances_with_auto_minor_version_upgrade_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_auto_minor_version_upgrade_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_auto_minor_version_upgrade_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/RDS"
  }
}

variable "rds_db_instances_with_auto_minor_version_upgrade_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_auto_minor_version_upgrade"]

  tags = {
    folder = "Advanced/RDS"
  }
}


trigger "query" "detect_and_correct_rds_db_instances_with_auto_minor_version_upgrade_disabled" {
  title         = "Detect & correct RDS DB instances with auto minor version upgrade disabled"
  description   = "Detect RDS DB instances with auto minor version upgrade disabled and then skip or enable auto minor version upgrade."
  tags          = local.rds_common_tags

  enabled  = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_trigger_enabled
  schedule = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_instances_with_auto_minor_version_upgrade_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instances_with_auto_minor_version_upgrade_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instances_with_auto_minor_version_upgrade_disabled" {
  title         = "Detect & correct RDS DB instances with auto minor version upgrade disabled"
  description   = "Detect RDS DB instances with auto minor version upgrade disabled and then skip or enable auto minor version upgrade."
  tags          = merge(local.rds_common_tags, { recommended = "true" })

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
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instances_with_auto_minor_version_upgrade_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instances_with_auto_minor_version_upgrade_disabled
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

pipeline "correct_rds_db_instances_with_auto_minor_version_upgrade_disabled" {
  title         = "Correct RDS DB instance with auto minor version upgrade disabled"
  description   = "Enable auto minor version upgrade on a collection of RDS DB instances with auto minor version upgrade disabled."
  tags          = merge(local.rds_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title                  = string
      db_instance_identifier = string
      auto_minor_version_upgrade = bool
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
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} RDS DB instance(s) with auto minor version upgrade disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.db_instance_identifier => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_with_auto_minor_version_upgrade_disabled
    args = {
      title                      = each.value.title
      db_instance_identifier     = each.value.db_instance_identifier
      auto_minor_version_upgrade = true
      region                     = each.value.region
      cred                       = each.value.cred
      notifier                   = param.notifier
      notification_level         = param.notification_level
      approvers                  = param.approvers
      default_action             = param.default_action
      enabled_actions            = param.enabled_actions
    }
  }
}

pipeline "correct_one_rds_db_instance_with_auto_minor_version_upgrade_disabled" {
  title         = "Correct one RDS DB instance with auto minor version upgrade disabled"
  description   = "Enable auto minor version upgrade on an RDS DB instance with auto minor version upgrade disabled."
  tags          = merge(local.rds_common_tags, { type = "internal" })

  param "title" {
    type        = string  
    description = local.description_title
  }

  param "db_instance_identifier" {
    type        = string
    description = "The identifier of DB instance."
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
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instances_with_auto_minor_version_upgrade_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB instance ${param.title} with auto minor version upgrade disabled."
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
            text     = "Skipped RDS DB instance ${param.title} with auto minor version upgrade disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_auto_minor_version_upgrade" = {
          label        = "Enable Auto Minor Version Upgrade"
          value        = "enable_auto_minor_version_upgrade"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.modify_rds_db_instance
          pipeline_args = {
            db_instance_identifier     = param.db_instance_identifier
            auto_minor_version_upgrade = true
            region                     = param.region
            cred                       = param.cred
          }
          success_msg = "Enabled auto minor version upgrade for RDS DB instance ${param.title}."
          error_msg   = "Error enabling auto minor version upgrade for RDS DB instance ${param.title}."
        }
      }
    }
  }
}
