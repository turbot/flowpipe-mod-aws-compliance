locals {
  regions_with_security_hub_disabled_query = <<-EOQ
    select
      concat('[', r.name, '/', r.account_id, ']') as title,
      r._ctx ->> 'connection_name' as cred,
      r.name as region
    from
      aws_region as r
      left join aws_securityhub_hub as h on r.account_id = h.account_id and r.name = h.region
    where
      h.hub_arn is null
      and r.opt_in_status != 'not-opted-in'
      and r.region != any(array['af-south-1', 'eu-south-1', 'cn-north-1', 'cn-northwest-1', 'ap-northeast-3']);
  EOQ
}

trigger "query" "detect_and_correct_regions_with_security_hub_disabled" {
  title       = "Detect & correct regions with Security Hub disabled"
  description = "Detects regions with Security Hub disabled and runs your chosen action."
  // documentation = file("./securityhub/docs/detect_and_correct_regions_with_security_hub_disabled_trigger.md")
  // tags          = merge(local.securityhub_common_tags, { class = "unused" })

  enabled  = var.regions_with_security_hub_disabled_trigger_enabled
  schedule = var.regions_with_security_hub_disabled_trigger_schedule
  database = var.database
  sql      = local.regions_with_security_hub_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_regions_with_security_hub_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_regions_with_security_hub_disabled" {
  title       = "Detect & correct regions with Security Hub disabled"
  description = "Detects regions with Security Hub disabled and runs your chosen action."
  // documentation = file("./securityhub/docs/detect_and_correct_regions_with_security_hub_disabled.md")
  // tags          = merge(local.securityhub_common_tags, { class = "unused", type = "featured" })

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
    default     = var.regions_with_security_hub_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_security_hub_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.regions_with_security_hub_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_regions_with_security_hub_disabled
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

pipeline "correct_regions_with_security_hub_disabled" {
  title       = "Correct regions with Security Hub disabled"
  description = "Executes corrective actions on regions with Security Hub disabled."
  // documentation = file("./securityhub/docs/correct_regions_with_security_hub_disabled_.md")
  // tags          = merge(local.securityhub_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title  = string
      region = string
      cred   = string
    }))
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
    default     = var.regions_with_security_hub_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_security_hub_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} unused Security Hub disableds."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_region_with_security_hub_disabled
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

pipeline "correct_one_region_with_security_hub_disabled" {
  title       = "Correct one region with Security Hub disabled"
  description = "Runs corrective action on a single regions with Security Hub disabled."
  // documentation = file("./securityhub/docs/correct_one_region_with_security_hub_disabled_.md")
  // tags          = merge(local.securityhub_common_tags, { class = "unused" })

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
    default     = var.regions_with_security_hub_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.regions_with_security_hub_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Security Hub disabled ${param.title} for region enabled."
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
            send     = param.notification_level == "verbose"
            text     = "Skipped Security Hub disabled ${param.title}."
          }
          success_msg = "Skipped Security Hub disabled ${param.title} for region enabled."
          error_msg   = "Error skipping Security Hub disabled ${param.title} for region enabled."
        },
        "enable_with_default_standards" = {
          label        = "Enable with Default Standards"
          value        = "enable_with_default_standards"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_enable_security_hub
          pipeline_args = {
            region                   = param.region
            enable_default_standards = true
            cred                     = param.cred
          }
          success_msg = "Enabled SecurityHub with default standards in region ${param.title}."
          error_msg   = "Error enabling SecurityHub with default standards in region ${param.title}."
        },
        "enable_without_default_standards" = {
          label        = "Enable without Default Standards"
          value        = "enable_without_default_standards"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_enable_security_hub
          pipeline_args = {
            region                   = param.region
            enable_default_standards = false
            cred                     = param.cred
          }
          success_msg = "Enabled SecurityHub without default standards in region ${param.title}."
          error_msg   = "Error enabling SecurityHub without default standards in region ${param.title}."
        }
      }
    }
  }
}

variable "regions_with_security_hub_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "regions_with_security_hub_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "regions_with_security_hub_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "regions_with_security_hub_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_with_default_standards", "enable_without_default_standards"]
}