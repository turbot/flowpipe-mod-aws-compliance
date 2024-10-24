locals {
  s3_buckets_with_default_encryption_disabled_query = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      name as bucket_name,
      region,
      sp_connection_name as conn
    from
      aws_s3_bucket
    where
      server_side_encryption_configuration is null;
  EOQ
}

variable "s3_buckets_with_default_encryption_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/S3"
  }
}

variable "s3_buckets_with_default_encryption_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/S3"
  }
}

trigger "query" "detect_and_correct_s3_buckets_with_default_encryption_disabled" {
  title       = "Detect & correct S3 buckets with default encryption disabled"
  description = "Detect S3 buckets with default encryption disabled."
  tags        = local.s3_common_tags

  enabled  = var.s3_buckets_with_default_encryption_disabled_trigger_enabled
  schedule = var.s3_buckets_with_default_encryption_disabled_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_default_encryption_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_default_encryption_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_default_encryption_disabled" {
  title       = "Detect & correct S3 buckets with default encryption disabled"
  description = "Detect S3 buckets with default encryption disabled."
  tags        = merge(local.s3_common_tags, { recommended = "true" })

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

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_default_encryption_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_default_encryption_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_s3_buckets_with_default_encryption_disabled" {
  title       = "Correct S3 buckets with default encryption disabled"
  description = "Send notifications for S3 buckets with default encryption disabled."
  tags        = merge(local.s3_common_tags, { folder = "Internal" })

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
    enum        = local.notification_level_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} S3 bucket(s) with default encryption disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected S3 bucket ${each.value.title} with default encryption disabled."
  }
}

