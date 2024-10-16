locals {
  ebs_snapshots_when_publicly_restorable_query = <<-EOQ
  select
    concat(snapshot_id, ' [', account_id, '/', region, ']') as title,
    snapshot_id,
    region,
    sp_connection_name as conn
  from
    aws_ebs_snapshot
  where
    create_volume_permissions @> '[{"Group": "all", "UserId": null}]';
  EOQ
}

variable "ebs_snapshots_when_publicly_restorable_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "ebs_snapshots_when_publicly_restorable_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "ebs_snapshots_when_publicly_restorable_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "ebs_snapshots_when_publicly_restorable_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_snapshot_permision_to_private", "delete_snapshot"]

  tags = {
    folder = "Advanced/EBS"
  }
}

trigger "query" "detect_and_correct_ebs_snapshots_when_publicly_restorable" {
  title         = "Detect & correct EBS snapshots when publicly restorable"
  description   = "Detect EBS snapshots that are publicly restorable and then skip or update snapshot permission to private or delete the snapshot."
  tags        = local.ebs_common_tags

  enabled  = var.ebs_snapshots_when_publicly_restorable_trigger_enabled
  schedule = var.ebs_snapshots_when_publicly_restorable_trigger_schedule
  database = var.database
  sql      = local.ebs_snapshots_when_publicly_restorable_query

  capture "insert" {
    pipeline = pipeline.correct_ebs_snapshots_when_publicly_restorable
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ebs_snapshots_when_publicly_restorable" {
  title         = "Detect & correct EBS snapshots when publicly restorable"
  description   = "Detect EBS snapshots that are publicly restorable and then skip or update snapshot permission to private or delete the snapshot."
  tags          = merge(local.ebs_common_tags, { recommended = "true" })

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
    default     = var.ebs_snapshots_when_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_when_publicly_restorable_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ebs_snapshots_when_publicly_restorable_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ebs_snapshots_when_publicly_restorable
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

pipeline "correct_ebs_snapshots_when_publicly_restorable" {
  title         = "Correct EBS snapshots when publicly restorable"
  description   = "Update snapshot permission to private or delete the snapshot on a collection of EBS snapshots that are publicly restorable."
  tags          = merge(local.ebs_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title       = string
      snapshot_id = string
      region      = string
      conn        = string
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
    default     = var.ebs_snapshots_when_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_when_publicly_restorable_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} EBS snapshot(s) that are publicly restorable."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.snapshot_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ebs_snapshot_when_publicly_restorable
    args = {
      title              = each.value.title
      snapshot_id        = each.value.snapshot_id
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

pipeline "correct_one_ebs_snapshot_when_publicly_restorable" {
  title         = "Correct one EBS snapshot when publicly restorable"
  description   = "Runs corrective action on an EBS snapshot if it is publicly restorable."
  tags          = merge(local.ebs_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "snapshot_id" {
    type        = string
    description = "The ID of the EBS snapshot."
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
    default     = var.ebs_snapshots_when_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_when_publicly_restorable_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected publicly restorable EBS snapshot ${param.title}."
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
            text     = "Skipped publicly restorable EBS snapshot ${param.title}"
          }
          success_msg = ""
          error_msg   = ""
        },
        // TODO: Is the pipeline correct?
        "update_snapshot_permision_to_private" = {
          label        = "Update Snapshot Permission to Private"
          value        = "update_snapshot_permision_to_private"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.modify_ebs_snapshot
          pipeline_args = {
            snapshot_id = param.snapshot_id
            region      = param.region
            conn        = param.conn
          }
          success_msg = "Updated EBS snapshot ${param.title} access permission to private."
          error_msg   = "Error updating EBS snapshot ${param.title} access permission to private."
        }
        "delete_snapshot" = {
          label        = "Delete Snapshot"
          value        = "delete_snapshot"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.delete_ebs_snapshot
          pipeline_args = {
            snapshot_id = param.snapshot_id
            region      = param.region
            conn        = param.conn
          }
          success_msg = "Deleted EBS snapshot ${param.title}."
          error_msg   = "Error deleting EBS snapshot ${param.title}."
        }
      }
    }
  }
}

