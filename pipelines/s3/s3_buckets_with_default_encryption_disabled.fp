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

trigger "query" "detect_and_correct_s3_buckets_with_default_encryption_disabled" {
  title       = "Detect & correct S3 Buckets With Default Encryption Disabled"
  description = "Detect S3 buckets with default encryption disabled and then skip or enable default encryption."
  // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_default_encryption_disabled_trigger.md")

  enabled  = var.s3_bucket_default_encryption_disabled_trigger_enabled
  schedule = var.s3_bucket_default_encryption_disabled_trigger_schedule
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
  title       = "Detect & correct S3 Buckets With Default Encryption Disabled"
  description = "Detect S3 buckets with default encryption disabled and then skip or enable default encryption."
  // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_default_encryption_disabled.md")
  tags = merge(local.s3_common_tags, { class = "security", recommended = "true" })

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
    default     = var.s3_bucket_default_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_default_encryption_disabled_enabled_actions
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
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_s3_buckets_with_default_encryption_disabled" {
  title       = "Correct S3 Buckets With Default Encryption Disabled"
  description = "Executes corrective actions on S3 buckets with default encryption disabled."
  // documentation = file("./s3/docs/correct_s3_buckets_with_default_encryption_disabled.md")
  

  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
      region      = string
      conn        = string
    }))
    description = local.description_items
  }

  param "sse_algorithm" {
    type        = string
    description = "The server-side encryption algorithm to use for the bucket."
    default     = var.sse_algorithm
  }

  param "bucket_key_enabled" {
    type        = bool
    description = "Specifies whether Amazon S3 should use an S3 Bucket Key with server-side encryption using AWS KMS (SSE-KMS)."
    default     = var.bucket_key_enabled
  }

  param "kms_master_key_id" {
    type        = string
    description = "The KMS master key ID to use for the bucket."
    default     = var.kms_master_key_id
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
    default     = var.s3_bucket_default_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_default_encryption_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} S3 bucket(s) with default encryption disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.bucket_name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_with_default_encryption_disabled
    args = {
      title              = each.value.title
      bucket_name        = each.value.bucket_name
      region             = each.value.region
      kms_master_key_id  = param.kms_master_key_id
      bucket_key_enabled = param.bucket_key_enabled
      sse_algorithm      = param.sse_algorithm
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_with_default_encryption_disabled" {
  title       = "Correct One S3 Bucket With Default Encryption Disabled"
  description = "Enable default encryption for a single S3 bucket."
  // documentation = file("./s3/docs/correct_one_s3_bucket_with_default_encryption_disabled.md")
  

  param "title" {
    type        = string
    description = "The title of the S3 bucket."
  }

  param "bucket_name" {
    type        = string
    description = "The name of the S3 bucket."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "sse_algorithm" {
    type        = string
    description = "The server-side encryption algorithm to use for the bucket."
    default     = var.sse_algorithm
  }

  param "bucket_key_enabled" {
    type        = bool
    description = "Specifies whether Amazon S3 should use an S3 Bucket Key with server-side encryption using AWS KMS (SSE-KMS)."
    default     = var.bucket_key_enabled
  }

  param "kms_master_key_id" {
    type        = string
    description = "The KMS master key ID to use for the bucket."
    default     = var.kms_master_key_id
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
    default     = var.s3_bucket_default_encryption_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_default_encryption_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected S3 bucket ${param.bucket_name} with default encryption disabled."
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
            text     = "Skipped S3 bucket ${param.bucket_name} with default encryption disabled."
          }
          success_msg = "Skipped S3 bucket ${param.bucket_name} with default encryption disabled."
          error_msg   = "Error skipping S3 bucket ${param.bucket_name} with default encryption disabled."
        },
        "enable_default_encryption" = {
          label        = "Enable Default Encryption"
          value        = "enable_default_encryption"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.put_s3_bucket_encryption
          pipeline_args = {
            bucket_name        = param.bucket_name
            kms_master_key_id  = param.kms_master_key_id
            bucket_key_enabled = param.bucket_key_enabled
            sse_algorithm      = param.sse_algorithm
            region             = param.region
            conn               = param.conn
          }
          success_msg = "Enabled default encryption for S3 bucket ${param.bucket_name}."
          error_msg   = "Failed to enable default encryption for S3 bucket ${param.bucket_name}."
        }
      }
    }
  }
}

variable "s3_bucket_default_encryption_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_bucket_default_encryption_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "s3_bucket_default_encryption_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "s3_bucket_default_encryption_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_default_encryption"]
}

variable "bucket_key_enabled" {
  type        = bool
  description = "Specifies whether Amazon S3 should use an S3 Bucket Key with server-side encryption using AWS KMS (SSE-KMS)."
  default     = true
}

variable "sse_algorithm" {
  type        = string
  description = "The server-side encryption algorithm to use for the bucket."
  default     = "aws:kms"
}

variable "kms_master_key_id" {
  type        = string
  description = "The KMS master key ID to use for the bucket."
  default     = "aws/s3"
}
