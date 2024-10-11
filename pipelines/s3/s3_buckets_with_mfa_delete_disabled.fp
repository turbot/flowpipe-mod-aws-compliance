locals {
  s3_buckets_with_mfa_delete_disabled_query = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      name as bucket_name,
      region,
      sp_connection_name as conn
    from
      aws_s3_bucket
    where
      not versioning_mfa_delete;
  EOQ
}

variable "s3_bucket_mfa_delete_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_bucket_mfa_delete_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "s3_bucket_mfa_delete_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "s3_bucket_mfa_delete_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["notify"]
}

trigger "query" "detect_and_correct_s3_buckets_with_mfa_delete_disabled" {
  title       = "Detect & correct S3 buckets with MFA delete disabled"
  description = "Detect S3 buckets with MFA delete disabled."
  // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_mfa_delete_disabled_trigger.md")

  enabled  = var.s3_bucket_mfa_delete_disabled_trigger_enabled
  schedule = var.s3_bucket_mfa_delete_disabled_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_mfa_delete_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_mfa_delete_disabled
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_s3_buckets_with_mfa_delete_disabled
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_mfa_delete_disabled" {
  title       = "Detect & correct S3 buckets with MFA delete disabled"
  description = "Detect S3 buckets with MFA delete disabled."
  // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_mfa_delete_disabled.md")

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
    default     = var.s3_bucket_mfa_delete_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_mfa_delete_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_mfa_delete_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_mfa_delete_disabled
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

pipeline "correct_s3_buckets_with_mfa_delete_disabled" {
  title       = "Correct S3 buckets with MFA delete disabled"
  description = "Detect S3 buckets with MFA delete disabled."
  // documentation = file("./s3/docs/correct_s3_buckets_with_mfa_delete_disabled.md")

  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
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
    default     = var.s3_bucket_mfa_delete_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_mfa_delete_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} S3 bucket(s) with MFA delete disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected S3 bucket ${each.value.title} with MFA delete disabled."
  }
}
