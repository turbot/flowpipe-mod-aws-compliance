locals {
  default_ebs_encryption_at_rest_disabled_in_regions_query = <<-EOQ
    select
      concat('[', r.account_id, '/', r.name, ']') as title,
      r._ctx ->> 'connection_name' as cred,
      r.name as region
    from
      aws_region as r
      left join aws_ec2_regional_settings as e on r.account_id = e.account_id and r.name = e.region
    where
      not e.default_ebs_encryption_enabled;
  EOQ
}

variable "default_ebs_encryption_at_rest_disabled_in_regions_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "default_ebs_encryption_at_rest_disabled_in_regions_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "default_ebs_encryption_at_rest_disabled_in_regions_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "default_ebs_encryption_at_rest_disabled_in_regions_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_default_encryption"]
}

trigger "query" "detect_and_correct_default_ebs_encryption_at_rest_disabled_in_regions" {
  title         = "Detect & correct default EBS encryption at rest disabled in regions"
  description   = "Detect regions with default encryption at rest disabled and then skip or enable encryption."
  // // documentation = file("./ebs/docs/detect_and_correct_default_ebs_encryption_at_rest_disabled_in_regions_trigger.md")
  tags          = merge(local.ebs_common_tags, { class = "security" })

  enabled  = var.default_ebs_encryption_at_rest_disabled_in_regions_trigger_enabled
  schedule = var.default_ebs_encryption_at_rest_disabled_in_regions_trigger_schedule
  database = var.database
  sql      = local.default_ebs_encryption_at_rest_disabled_in_regions_query

  capture "insert" {
    pipeline = pipeline.correct_default_ebs_encryption_at_rest_disabled_in_regions
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_default_ebs_encryption_at_rest_disabled_in_regions" {
  title         = "Detect & correct default EBS encryption at rest disabled in regions"
  description   = "Detect regions with default encryption at rest disabled and then skip or enable encryption."
  // // documentation = file("./ebs/docs/detect_and_correct_default_ebs_encryption_at_rest_disabled_in_regions.md")
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
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.default_ebs_encryption_at_rest_disabled_in_regions_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_default_ebs_encryption_at_rest_disabled_in_regions
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

pipeline "correct_default_ebs_encryption_at_rest_disabled_in_regions" {
  title         = "Correct default EBS encryption at rest disabled in regions"
  description   = "Enable EBS default encryption at rest in regions with default encryption at rest disabled."
  // // documentation = file("./ebs/docs/correct_default_ebs_encryption_at_rest_disabled_in_regions.md")
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
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EBS region(s) with default encryption at rest disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ebs_region_with_default_encryption_at_rest_disabled
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

pipeline "correct_one_ebs_region_with_default_encryption_at_rest_disabled" {
  title         = "Correct one EBS region with default encryption at rest disabled"
  description   = "Enable default encryption at rest on a single EBS region with default encryption at rest disabled."
  // // documentation = file("./ebs/docs/correct_one_ebs_region_with_default_encryption_at_rest_disabled.md")
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
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.default_ebs_encryption_at_rest_disabled_in_regions_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EBS region ${param.title} with default encryption at rest disabled."
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
            text     = "Skipped EBS region ${param.title} with default encryption at rest disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_default_encryption" = {
          label        = "Enable Default Encryption"
          value        = "enable_default_encryption"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.enable_ebs_encryption_by_default
          pipeline_args = {
            region    = param.region
            cred      = param.cred
          }
          success_msg = "Enabled default encryption for EBS region ${param.title}."
          error_msg   = "Error enabling default encryption for EBS region ${param.title}."
        }
      }
    }
  }
}

