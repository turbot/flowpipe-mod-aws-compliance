locals {
  expired_iam_server_certificate_query = <<-EOQ
    select
      concat(server_certificate_id, ' [', region, '/', account_id, ']') as title,
      region,
      name,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_server_certificate
    where
      expiration < (current_date - interval '1' second);
  EOQ
}

trigger "query" "detect_and_correct_expired_iam_server_certificates" {
  title       = "Detect & Correct expired IAM server certificates"
  description = "Detects expired IAM server certificates and executes the chosen action."
  // tags        = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.expired_iam_server_certificate_trigger_enabled
  schedule = var.expired_iam_server_certificate_trigger_schedule
  database = var.database
  sql      = local.expired_iam_server_certificate_query

  capture "insert" {
    pipeline = pipeline.correct_expired_iam_server_certificate
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_expired_iam_server_certificates" {
  title       = "Detect & Correct expired IAM server certificates"
  description = "Detects expired IAM server certificates and performs the chosen action."
  // tags        = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.expired_iam_server_certificate_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.expired_iam_server_certificate_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.expired_iam_server_certificate_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_expired_iam_server_certificate
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

pipeline "correct_expired_iam_server_certificate" {
  title       = "Correct expired IAM server certificates"
  description = "Executes corrective actions on expired IAM server certificates."
  // tags        = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title  = string,
      name   = string,
      region = string,
      cred   = string,
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
    default     = var.expired_iam_server_certificate_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.expired_iam_server_certificate_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} expired IAM server certificate."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.instance_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_expired_iam_server_certificate
    args = {
      title              = each.value.title,
      name               = each.value.name,
      region             = each.value.region,
      cred               = each.value.cred,
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_expired_iam_server_certificate" {
  title       = "Correct one expired IAM server certificate"
  description = "Runs corrective action on an expired IAM server certificate."
  // tags        = merge(local.iam_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the expired IAM certificate."
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
    default     = var.expired_iam_server_certificate_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.expired_iam_server_certificate_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      detect_msg         = "Detected expired IAM server certificate ${param.title}.",
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions,
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped expired IAM server certificate ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_iam_server_certificate" = {
          label        = "Delete IAM Server Certificate"
          value        = "delete_iam_server_certificate"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_delete_iam_server_certificate
          pipeline_args = {
            server_certificate_name = param.name
            cred                    = param.cred
          }
          success_msg = "Deleted IAM Server Certificate ${param.title}."
          error_msg   = "Error deleting IAM Server Certificate ${param.title}."
        }
      }
    }
  }
}

variable "expired_iam_server_certificate_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "expired_iam_server_certificate_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "expired_iam_server_certificate_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use for the detected item, used if no input is provided."
}

variable "expired_iam_server_certificate_enabled_actions" {
  type        = list(string)
  default     = ["skip", "delete_iam_server_certificate"]
  description = "The list of enabled actions to provide for selection."
}
