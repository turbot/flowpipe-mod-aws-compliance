locals {
  cloudtrail_trails_with_s3_logging_disabled_query = <<-EOQ
  select
    concat(t.name, ' [', t.region, '/', t.account_id, ']') as title,
    t.arn as resource,
    t.name,
    t.region,
    t.account_id,
    t.sp_connection_name as conn
  from
    aws_cloudtrail_trail t
    inner join aws_s3_bucket b on t.s3_bucket_name = b.name
  where
    t.region = t.home_region
    and b.logging is null;
  EOQ

  cloudtrail_trails_with_s3_logging_disabled_default_action_enum  = ["notify", "skip", "enable_s3_logging"]
  cloudtrail_trails_with_s3_logging_disabled_enabled_actions_enum = ["skip", "enable_s3_logging"]
}

variable "cloudtrail_trails_with_s3_logging_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_s3_logging_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_s3_logging_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "enable_s3_logging"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_s3_logging_disabled_enabled_actions" {
  type        = list(string)
  description = " The list of enabled actions approvers can select."
  default     = ["skip", "enable_s3_logging"]
  enum        = ["skip", "enable_s3_logging"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_s3_logging_disabled_default_bucket_name" {
  type        = string
  description = "The name of the bucket."
  default     = "test-fp-bucket-trail-logging"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_s3_logging_disabled" {
  title       = "Detect & correct CloudTrail trails with S3 logging disabled"
  description = "Detect CloudTrail trails with S3 logging disabled and then enable S3 logging."

  tags = merge(local.cloudtrail_common_tags)

  enabled  = var.cloudtrail_trails_with_s3_logging_disabled_trigger_enabled
  schedule = var.cloudtrail_trails_with_s3_logging_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_s3_logging_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_logging_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_s3_logging_disabled" {
  title       = "Detect & correct CloudTrail trails with S3 logging disabled"
  description = "Detect CloudTrail trails with S3 logging disabled and then enable S3 logging."

  tags = merge(local.cloudtrail_common_tags, { recommended = "true" })

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

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_bucket_name
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_enabled_actions
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_s3_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_logging_disabled
    args = {
      items              = step.query.detect.rows
      bucket_name        = param.bucket_name
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_cloudtrail_trails_with_s3_logging_disabled" {
  title       = "Correct CloudTrail trails with S3 logging disabled"
  description = "Enable S3 logging for CloudTrail trails with S3 logging disabled."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title      = string
      name       = string
      region     = string
      account_id = string
      conn       = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_bucket_name
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
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_enabled_actions
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected CloudTrail trail(s) ${length(param.items)} with S3 logging disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_s3_logging_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      bucket_name        = param.bucket_name
      region             = each.value.region
      account_id         = each.value.account_id
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_with_s3_logging_disabled" {
  title       = "Correct one CloudTrail trail with S3 logging disabled"
  description = "Enable S3 logging for a CloudTrail trail."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "bucket_name" {
    type        = string
    description = "The name of the S3 Bucket."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "account_id" {
    type        = string
    description = "The ID of the AWS account."
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
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_enabled_actions
    enum        = local.cloudtrail_trails_with_s3_logging_disabled_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail ${param.title} with S3 logging disabled."
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
            text     = "Skipped CloudTrail trail ${param.title} with S3 logging disabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_s3_logging" = {
          label        = "Enable S3 logging"
          value        = "enable_s3_logging"
          style        = local.style_alert
          pipeline_ref = pipeline.enable_s3_logging_for_cloudtrail
          pipeline_args = {
            conn           = param.conn
            trail_name     = param.name
            s3_bucket_name = param.bucket_name
            region         = param.region
            account_id     = param.account_id
          }
          success_msg = "Enabled S3 logging for CloudTrail trail ${param.title}."
          error_msg   = "Error enabling S3 logging for CloudTrail trail ${param.title}."
        }
      }
    }
  }
}

pipeline "enable_s3_logging_for_cloudtrail" {
  title       = "Enable S3 logging for Cloudtrail trail"
  description = "Enable S3 logging for Cloudtrail trail."
  tags        = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "region" {
    type        = string
    description = local.description_region
  }

  param "account_id" {
    type        = string
    description = "The AWS account ID in which to create the CloudTrail trail."
  }

  param "conn" {
    type        = connection.aws
    description = "The AWS connections to use for creating the trail."
    default     = connection.aws.default
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
  }

  // The pipeline should not create any bucket.
  // User could create a S3 bucket, apply appropriate policy to it beforehand and then set that in the var.
  step "pipeline" "update_cloudtrail_trail" {
    pipeline = aws.pipeline.update_cloudtrail_trail
    args = {
      region         = param.region
      trail_name     = param.trail_name
      conn           = param.conn
      s3_bucket_name = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_logging" {
    depends_on = [step.pipeline.update_cloudtrail_trail]
    pipeline   = aws.pipeline.put_s3_bucket_logging
    args = {
      conn                  = param.conn
      region                = param.region
      bucket                = param.s3_bucket_name
      bucket_logging_status = "{\"LoggingEnabled\": {\"TargetBucket\": \"${param.s3_bucket_name}\", \"TargetPrefix\": \"AWSLogs/\"}}"
    }
  }
}
