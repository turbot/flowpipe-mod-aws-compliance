locals {
  ebs_snapshots_if_publicly_restorable_query = <<-EOQ
  select
    concat(snapshot_id, ' [', region, '/', account_id, ']') as title,
    snapshot_id,
    region,
    _ctx ->> 'connection_name' as cred
  from
    aws_ebs_snapshot
  where
    create_volume_permissions @> '[{"Group": "all", "UserId": null}]';
  EOQ
}

trigger "query" "detect_and_correct_ebs_snapshots_if_publicly_restorable" {
  title         = "Detect & correct EBS snapshots if publicly restorable"
  description   = "Detects EBS snapshots that are publicly restorable and runs your chosen action."
  // documentation = file("./ebs/docs/detect_and_correct_ebs_snapshots_if_publicly_restorable_trigger.md")
  tags          = merge(local.ebs_common_tags, { class = "unused" })

  enabled  = var.ebs_snapshots_if_publicly_restorable_trigger_enabled
  schedule = var.ebs_snapshots_if_publicly_restorable_trigger_schedule
  database = var.database
  sql      = local.ebs_snapshots_if_publicly_restorable_query

  capture "insert" {
    pipeline = pipeline.correct_ebs_snapshots_if_publicly_restorable
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ebs_snapshots_if_publicly_restorable" {
  title         = "Detect & correct EBS snapshots if publicly restorable"
  description   = "Detects EBS snapshots that are publicly restorable and runs your chosen action."
  // documentation = file("./ebs/docs/detect_and_correct_ebs_snapshots_if_publicly_restorable.md")
  tags          = merge(local.ebs_common_tags, { class = "unused", type = "featured" })

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
    default     = var.ebs_snapshots_if_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_if_publicly_restorable_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ebs_snapshots_if_publicly_restorable_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ebs_snapshots_if_publicly_restorable
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

pipeline "correct_ebs_snapshots_if_publicly_restorable" {
  title         = "Correct EBS snapshots if publicly restorable"
  description   = "Runs corrective action on a collection of EBS snapshots that are publicly restorable."
  // documentation = file("./ebs/docs/correct_ebs_snapshots_if_publicly_restorable.md")
  tags          = merge(local.ebs_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title       = string
      snapshot_id = string
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
    default     = var.ebs_snapshots_if_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_if_publicly_restorable_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EBS snapshots that are publicly restorable."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.snapshot_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ebs_snapshot_publicly_restorable
    args = {
      title              = each.value.title
      snapshot_id        = each.value.snapshot_id
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

pipeline "correct_one_ebs_snapshot_publicly_restorable" {
  title         = "Correct one EBS snapshot if publicly restorable"
  description   = "Runs corrective action on an EBS snapshot if it is publicly restorable."
  // documentation = file("./ebs/docs/correct_one_ebs_snapshot_publicly_restorable.md")
  tags          = merge(local.ebs_common_tags, { class = "unused" })

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
    default     = var.ebs_snapshots_if_publicly_restorable_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_snapshots_if_publicly_restorable_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EBS snapshots ${param.title} that are publicly restorable."
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
            text     = "Skipped EBS snapshot ${param.title} that are publicly restorable."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_snapshot_permision_to_private" = {
          label        = "Update Snapshot Permission to Private"
          value        = "update_snapshot_permision_to_private"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_ebs_snapshot
          pipeline_args = {
            snapshot_id = param.snapshot_id
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Updated EBS snapshot ${param.title} access permission to private."
          error_msg   = "Error updating EBS snapshot ${param.title} access permission to private."
        }
        "delete_snapshot" = {
          label        = "Delete Snapshot"
          value        = "delete_snapshot"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_delete_ebs_snapshot
          pipeline_args = {
            snapshot_id = param.snapshot_id
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Deleted EBS snapshot ${param.title}."
          error_msg   = "Error deleting EBS snapshot ${param.title}."
        }
      }
    }
  }
}

variable "ebs_snapshots_if_publicly_restorable_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ebs_snapshots_if_publicly_restorable_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "ebs_snapshots_if_publicly_restorable_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "ebs_snapshots_if_publicly_restorable_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_snapshot_permision_to_private", "delete_snapshot"]
}
