locals {
  regions_with_ebs_encryption_by_default_disabled_query = <<-EOQ
    select
      concat('[', r.account_id, '/', r.name, ']') as title,
      r.sp_connection_name as conn,
      r.name as region
    from
      aws_region as r
      left join aws_ec2_regional_settings as e on r.account_id = e.account_id and r.name = e.region
    where
      not e.default_ebs_encryption_enabled;
  EOQ

  regions_with_ebs_encryption_by_default_disabled_default_action_enum  = ["notify", "skip", "enable_encryption_by_default"]
  regions_with_ebs_encryption_by_default_disabled_enabled_actions_enum = ["skip", "enable_encryption_by_default"]
}

variable "regions_with_ebs_encryption_by_default_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "regions_with_ebs_encryption_by_default_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "regions_with_ebs_encryption_by_default_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "enable_encryption_by_default"]

  tags = {
    folder = "Advanced/EBS"
  }
}

variable "regions_with_ebs_encryption_by_default_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_encryption_by_default"]
  enum        = ["skip", "enable_encryption_by_default"]

  tags = {
    folder = "Advanced/EBS"
  }
}

trigger "query" "detect_and_correct_regions_with_ebs_encryption_by_default_disabled" {
  title       = "Detect & correct regions with EBS encryption by default disabled"
  description = "Detect regions with EBS encryption by default disabled and then skip or enable encryption."

  tags = local.ebs_common_tags

  enabled  = var.regions_with_ebs_encryption_by_default_disabled_trigger_enabled
  schedule = var.regions_with_ebs_encryption_by_default_disabled_trigger_schedule
  database = var.database
  sql      = local.regions_with_ebs_encryption_by_default_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_regions_with_ebs_encryption_by_default_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_regions_with_ebs_encryption_by_default_disabled" {
  title       = "Detect & correct regions with EBS encryption by default disabled"
  description = "Detect regions with EBS encryption by default disabled and then skip or enable encryption."

  tags = merge(local.ebs_common_tags, { recommended = "true" })

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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.regions_with_ebs_encryption_by_default_disabled_default_action
    enum        = local.regions_with_ebs_encryption_by_default_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_ebs_encryption_by_default_disabled_enabled_actions
    enum        = local.regions_with_ebs_encryption_by_default_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.regions_with_ebs_encryption_by_default_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_regions_with_ebs_encryption_by_default_disabled
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

pipeline "correct_regions_with_ebs_encryption_by_default_disabled" {
  title       = "Correct regions with EBS encryption by default disabled"
  description = "Enable EBS encryption by default in regions with EBS encryption by default disabled."

  tags = merge(local.ebs_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title  = string
      region = string
      conn   = string
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.regions_with_ebs_encryption_by_default_disabled_default_action
    enum        = local.regions_with_ebs_encryption_by_default_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_ebs_encryption_by_default_disabled_enabled_actions
    enum        = local.regions_with_ebs_encryption_by_default_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} region(s) with EBS encryption by default disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_region_with_ebs_encryption_by_default_disabled
    args = {
      title              = each.value.title
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

pipeline "correct_one_region_with_ebs_encryption_by_default_disabled" {
  title       = "Correct one region with EBS encryption by default disabled"
  description = "Enable EBS encryption by default in one region with EBS encryption by default disabled."

  tags = merge(local.ebs_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.regions_with_ebs_encryption_by_default_disabled_default_action
    enum        = local.regions_with_ebs_encryption_by_default_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_ebs_encryption_by_default_disabled_enabled_actions
    enum        = local.regions_with_ebs_encryption_by_default_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected region ${param.title} with EBS encryption by default disabled."
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
            text     = "Skipped region ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_encryption_by_default" = {
          label        = "Enable encryption by default"
          value        = "enable_encryption_by_default"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.enable_ebs_encryption_by_default
          pipeline_args = {
            region = param.region
            conn   = param.conn
          }
          success_msg = "Enabled EBS encryption by default for region ${param.title}."
          error_msg   = "Error enabling EBS encryption by default for region ${param.title}."
        }
      }
    }
  }
}

