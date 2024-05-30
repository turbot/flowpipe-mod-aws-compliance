locals {

  rds_db_instance_if_iam_authentication_disabled_query = <<-EOQ
    select
      concat(db_instance_identifier, ' [', region, '/', account_id, ']') as title,
      db_instance_identifier,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_rds_db_instance
    where
      not iam_database_authentication_enabled;
  EOQ
}

trigger "query" "detect_and_correct_rds_db_instance_if_iam_authentication_disabled" {
  title         = "Detect & Correct RDS DB instance if IAM authentication disabled"
  description   = "Detects RDS DB instances if IAM authentication is disabled and runs your chosen action."
  // // documentation = file("./rds/docs/detect_and_correct_rds_db_instance_if_iam_authentication_disabled_trigger.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  enabled  = var.rds_db_instance_if_iam_authentication_disabled_trigger_enabled
  schedule = var.rds_db_instance_if_iam_authentication_disabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_instance_if_iam_authentication_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instance_if_iam_authentication_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instance_if_iam_authentication_disabled" {
  title         = "Detect & Correct RDS DB instances if IAM authentication disabled"
  description   = "Detects RDS DB instances if IAM authentication is disabled and runs your chosen action."
  // // documentation = file("./rds/docs/detect_and_correct_rds_db_instance_if_iam_authentication_disabled.md")
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
    default     = var.rds_db_instance_if_iam_authentication_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_iam_authentication_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instance_if_iam_authentication_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instance_if_iam_authentication_disabled
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

pipeline "correct_rds_db_instance_if_iam_authentication_disabled" {
  title         = "Correct RDS DB instance if IAM authentication disabled"
  description   = "Runs corrective action on a collection of RDS DB instance if IAM authentication is disabled."
  // // documentation = file("./rds/docs/correct_rds_db_instance_if_iam_authentication_disabled.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title                  = string
      db_instance_identifier = string
      iam_database_authentication_enabled = bool
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
    default     = var.rds_db_instance_if_iam_authentication_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_iam_authentication_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} RDS DB instance if IAM authentication is disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_instance_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_if_iam_authentication_disabled
    args = {
      title                  = each.value.title
      db_instance_identifier = each.value.db_instance_identifier
      iam_database_authentication_enabled = true
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

pipeline "correct_one_rds_db_instance_if_iam_authentication_disabled" {
  title         = "Correct one RDS DB instance if IAM authentication is disabled"
  description   = "Runs corrective action on an RDS DB instance if IAM authentication is disabled."
  // // documentation = file("./rds/docs/correct_one_rds_db_instance_if_iam_authentication_disabled.md")
  tags          = merge(local.rds_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "db_instance_identifier" {
    type        = string
    description = "The identifier of DB instance."
  }

  param "iam_database_authentication_enabled" {
    type        = bool
    description = "Enables the IAM database authentication property of a DB instance"
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
    default     = var.rds_db_instance_if_iam_authentication_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_if_iam_authentication_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB instance with IAM authentication disabled ${param.title}."
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
            text     = "Skipped RDS DB instance ${param.title} with IAM authentication disabled."
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
            db_instance_identifier               = param.db_instance_identifier
            iam_database_authentication_enabled  = true
            region                               = param.region
            cred                                 = param.cred
          }
          success_msg = "Updated RDS DB instance ${param.title}."
          error_msg   = "Error updating RDS DB instance ${param.title}."
        }
      }
    }
  }
}

variable "rds_db_instance_if_iam_authentication_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_instance_if_iam_authentication_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "rds_db_instance_if_iam_authentication_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "rds_db_instance_if_iam_authentication_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_db_instance"]
}
