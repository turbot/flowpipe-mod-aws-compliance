locals {
  ebs_volumes_with_encryption_at_rest_disabled_query = <<-EOQ
    select
      concat(volume_id, ' [', account_id, '/', region, ']') as title,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_ebs_volume
    where
      not encrypted;
  EOQ
}

variable "ebs_volumes_with_encryption_at_rest_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ebs_volumes_with_encryption_at_rest_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "ebs_volumes_with_encryption_at_rest_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "ebs_volumes_with_encryption_at_rest_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_encryption"]
}

trigger "query" "detect_and_correct_ebs_volumes_with_encryption_at_rest_disabled" {
  title         = "Detect & correct EBS volumes with encryption at rest disabled"
  description   = "Detect EBS volumes with encryption at rest disabled and then skip or enable encryption."
  // // documentation = file("./ebs/docs/detect_and_correct_ebs_volumes_with_encryption_at_rest_disabled_trigger.md")
  tags          = merge(local.ebs_common_tags, { class = "security" })

  enabled  = var.ebs_volumes_with_encryption_at_rest_disabled_trigger_enabled
  schedule = var.ebs_volumes_with_encryption_at_rest_disabled_trigger_schedule
  database = var.database
  sql      = local.ebs_volumes_with_encryption_at_rest_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_ebs_volumes_with_encryption_at_rest_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ebs_volumes_with_encryption_at_rest_disabled" {
  title         = "Detect & correct EBS volumes with encryption at rest disabled"
  description   = "Detect EBS volumes with encryption at rest disabled and then skip or enable encryption."
  // // documentation = file("./ebs/docs/detect_and_correct_ebs_volumes_with_encryption_at_rest_disabled.md")
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
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ebs_volumes_with_encryption_at_rest_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ebs_volumes_with_encryption_at_rest_disabled
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

pipeline "correct_ebs_volumes_with_encryption_at_rest_disabled" {
  title         = "Correct EBS volumes with encryption at rest disabled"
  description   = "Executes corrective actions on EBS volumes with encryption at rest disabled."
  // // documentation = file("./ebs/docs/correct_ebs_volumes_with_encryption_at_rest_disabled.md")
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
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EBS volume(s) with encryption at rest disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ebs_volumes_with_encryption_at_rest_disabled
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

pipeline "correct_one_ebs_volumes_with_encryption_at_rest_disabled" {
  title         = "Correct one EBS volume with encryption at rest disabled"
  description   = "Runs corrective action on a single EBS volume with encryption at rest disabled."
  // // documentation = file("./ebs/docs/correct_one_ebs_volumes_with_encryption_at_rest_disabled.md")
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
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ebs_volumes_with_encryption_at_rest_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EBS volume ${param.title} with encryption at rest disabled."
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
            text     = "Skipped EBS volume ${param.title} with encryption at rest disabled."
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

