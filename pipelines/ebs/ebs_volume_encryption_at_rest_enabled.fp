locals {
  ebs_volume_encryption_at_rest_enabled_query = <<-EOQ
    select
      concat(volume_id, ' [', region, '/', account_id, ']') as title,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_ebs_volume
    where
      not encrypted;
  EOQ
}

trigger "query" "detect_and_correct_ebs_volume_encryption_at_rest_enabled" {
  title         = "Detect & correct EBS Volumes Without Encryption At Rest"
  description   = "Detects EBS volumes without encryption at rest and runs your chosen action."
  // // documentation = file("./ebs/docs/detect_and_correct_ebs_volume_encryption_at_rest_enabled_trigger.md")
  tags          = merge(local.ebs_common_tags, { class = "security" })

  enabled  = var.ebs_volume_encryption_at_rest_enabled_trigger_enabled
  schedule = var.ebs_volume_encryption_at_rest_enabled_trigger_schedule
  database = var.database
  sql      = local.ebs_volume_encryption_at_rest_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_ebs_volume_encryption_at_rest_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ebs_volume_encryption_at_rest_enabled" {
  title         = "Detect & correct EBS Volumes Without Encryption At Rest"
  description   = "Detects EBS volumes without encryption at rest and runs your chosen action."
  // // documentation = file("./ebs/docs/detect_and_correct_ebs_volume_encryption_at_rest_enabled.md")
  tags          = merge(local.ebs_common_tags, { class = "security", type = "featured" })

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
    default     = var.ebs_volume_encryption_at_rest_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volume_encryption_at_rest_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ebs_volume_encryption_at_rest_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ebs_volume_encryption_at_rest_enabled
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

pipeline "correct_ebs_volume_encryption_at_rest_enabled" {
  title         = "Correct EBS Volumes Without Encryption At Rest"
  description   = "Executes corrective actions on EBS volumes without encryption at rest."
  // // documentation = file("./ebs/docs/correct_ebs_volume_encryption_at_rest_enabled.md")
  tags          = merge(local.ebs_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title       = string
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
    default     = var.ebs_volume_encryption_at_rest_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volume_encryption_at_rest_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EBS volumes without encryption at rest."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ebs_volume_encryption_at_rest_enabled
    args = {
      title              = each.value.title
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

pipeline "correct_one_ebs_volume_encryption_at_rest_enabled" {
  title         = "Correct One EBS Volume Without Encryption At Rest"
  description   = "Runs corrective action on a single EBS volume without encryption at rest."
  // // documentation = file("./ebs/docs/correct_one_ebs_volume_encryption_at_rest_enabled.md")
  tags          = merge(local.ebs_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
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
    default     = var.ebs_volume_encryption_at_rest_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volume_encryption_at_rest_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EBS volume ${param.title} without encryption at rest."
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
            text     = "Skipped EBS volume ${param.title} without encryption at rest."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_encryption" = {
          label        = "Enable Encryption"
          value        = "enable_encryption"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_enable_ebs_volume_encryption
          pipeline_args = {
            region    = param.region
            cred      = param.cred
          }
          success_msg = "Enabled encryption for EBS volume ${param.title}."
          error_msg   = "Error enabling encryption for EBS volume ${param.title}."
        }
      }
    }
  }
}

variable "ebs_volume_encryption_at_rest_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ebs_volume_encryption_at_rest_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "ebs_volume_encryption_at_rest_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "ebs_volume_encryption_at_rest_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_encryption"]
}
