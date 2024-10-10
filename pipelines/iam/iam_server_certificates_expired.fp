locals {
  iam_server_certificates_expired_query = <<-EOQ
    select
      (name, ' [', account_id, ']') as title,
      name as server_certificate_name,
      to_char(expiration, 'DD-Mon-YYYY') as expiration_date,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_server_certificate
    where
      expiration < (current_date - interval '1' second);
  EOQ
}

variable "iam_server_certificates_expired_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_server_certificates_expired_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_server_certificates_expired_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "delete_expired_server_certificate"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_server_certificates_expired_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_expired_server_certificate"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_server_certificates_expired" {
  title         = "Detect & correct expired IAM server certificates"
  description   = "Detects IAM server certificates which are expired and then delete them."
  tags          = local.iam_common_tags

  enabled  = var.iam_server_certificates_expired_trigger_enabled
  schedule = var.iam_server_certificates_expired_trigger_schedule
  database = var.database
  sql      = local.iam_server_certificates_expired_query

  capture "insert" {
    pipeline = pipeline.correct_iam_server_certificates_expired
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_server_certificates_expired" {
  title         = "Detect & correct expired IAM server certificates"
  description   = "Detects IAM server certificates which are expired and then delete them."
  tags          = local.iam_common_tags

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
    default     = var.iam_server_certificates_expired_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_server_certificates_expired_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_server_certificates_expired_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_server_certificates_expired
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

pipeline "correct_iam_server_certificates_expired" {
  title         = "Correct expired IAM server certificates"
  description   = "Runs corrective action to delete the expired IAM server certificates."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title                   = string
      server_certificate_name = string
      account_id              = string
      expiration_date         = string
      cred                    = string
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
    default     = var.iam_server_certificates_expired_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_server_certificates_expired_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} expired IAM server certificate(s)."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_server_certificate_expired
    args = {
      title                   = each.value.title
      server_certificate_name = each.value.server_certificate_name
      expiration_date         = each.value.expiration_date
      account_id              = each.value.account_id
      cred                    = each.value.cred
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_server_certificate_expired" {
  title         = "Correct one expired IAM server certificate"
  description   = "Runs corrective action to delete the expired IAM server certificate."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "server_certificate_name" {
    type        = string
    description = "The name of the IAM server certificate."
  }

  param "expiration_date" {
    type        = string
    description = "The expiration date of the IAM server certificate in the format YYYY-MM-DD."
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
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
    default     = var.iam_server_certificates_expired_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_server_certificates_expired_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM server certificate ${param.title} expired on ${param.expiration_date}."
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
            text     = "Skipped IAM server certificate ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_expired_server_certificate" = {
          label        = "Delete expired IAM server certificate"
          value        = "delete_expired_server_certificate"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.delete_iam_server_certificate
          pipeline_args = {
            server_certificate_name = param.server_certificate_name
            cred                    = param.cred
          }
          success_msg = "Deleted IAM server certificate ${param.title} expired on ${param.expiration_date}."
          error_msg   = "Error deleting IAM server certificate ${param.title} expired on ${param.expiration_date}."
        }
      }
    }
  }
}

pipeline "delete_iam_server_certificate" {
  title       = "Delete IAM server certificate"
  description = "Delete the specified IAM server certificate."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "server_certificate_name" {
    type        = string
    description = "The name of the IAM server certificate to be deleted."
  }

  step "container" "delete_iam_server_certificate" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "delete-server-certificate",
      "--server-certificate-name", param.server_certificate_name
    ]

    env = credential.aws[param.cred].env
  }
}

