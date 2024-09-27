locals {
  cloudtrail_trails_with_s3_logging_disabled_query = <<-EOQ
  select
    concat(t.name, ' [', region, '/', t.account_id, ']') as title,
    t.arn as resource,
    t.name,
    t.region,
    t.account_id,
    (select concat('fp-', to_char(now(), 'yyyy-mm-dd-hh24-mi-ss'))) as unique_string,
    t._ctx ->> 'connection_name' as cred
  from
    aws_cloudtrail_trail t
    inner join aws_s3_bucket b on t.s3_bucket_name = b.name
  where
    t.region = t.home_region
    and b.logging is null;
  EOQ
}

variable "cloudtrail_trails_with_s3_logging_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trails_with_s3_logging_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "cloudtrail_trails_with_s3_logging_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "cloudtrail_trails_with_s3_logging_disabled_default_actions" {
  type        = list(string)
  description = " The list of enabled actions approvers can select."
  default     = ["skip", "enable_s3_logging"]
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_s3_logging_disabled" {
  title         = "Detect & correct CloudTrail trails with S3 logging disabled"
  description   = "Detect CloudTrail trails with S3 logging disabled and then skip or enable S3 logging."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_s3_logging_disabled_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

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
  title         = "Detect & correct CloudTrail trails with S3 logging disabled"
  description   = "Detect CloudTrail trails with S3 logging disabled and then skip or enable S3 logging."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_s3_logging_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused", type = "featured" })

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
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_s3_logging_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_logging_disabled
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

pipeline "correct_cloudtrail_trails_with_s3_logging_disabled" {
  title         = "Correct CloudTrail trails with S3 logging disabled"
  description   = "Runs corrective action on a collection of CloudTrail trails with S3 logging disabled."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trails_with_s3_logging_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title         = string
      name          = string
      unique_string = string
      region        = string
      account_id    = string
      cred          = string
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
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trail(s) with S3 logging disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : row.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_s3_logging_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      bucket_name        = each.value.unique_string
      region             = each.value.region
      account_id         = each.value.account_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_with_s3_logging_disabled" {
  title         = "Correct one CloudTrail trail with S3 logging disabled"
  description   = "Runs corrective action on a CloudTrail trail with S3 logging disabled."
  // documentation = file("./cloudtrail/docs/correct_one_cloudtrail_trail_with_s3_logging_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

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
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_logging_disabled_default_actions
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
          label        = "Enable S3 Logging"
          value        = "enable_s3_logging"
          style        = local.style_alert
          pipeline_ref = pipeline.enable_s3_logging_for_cloudtrail
          pipeline_args = {
            cred           = param.cred
            trail_name     = param.name
            s3_bucket_name = param.bucket_name
            region         = param.region
            account_id     = param.account_id
          }
          success_msg = "Updated CloudTrail trail ${param.title} by enabling S3 logging."
          error_msg   = "Error updating S3 logging for ${param.title}."
        }
      }
    }
  }
}

pipeline "enable_s3_logging_for_cloudtrail" {
  title       = "Enable S3 logging for Cloudtrail trail"
  description = "Enable S3 logging for Cloudtrail trail."

  param "region" {
    type        = string
    description = "The AWS region in which to create the CloudTrail trail."
  }

  param "account_id" {
    type        = string
    description = "The AWS account ID in which to create the CloudTrail trail."
  }

  param "cred" {
    type        = string
    description = "The AWS credentials to use for creating the trail."
    default     = "default"
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
  }

  step "pipeline" "create_s3_bucket" {
    pipeline = aws.pipeline.create_s3_bucket
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.s3_bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}/AWSLogs/${param.account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "update_cloudtrail_trail" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.update_cloudtrail_trail
    args = {
      region         = param.region
      trail_name     = param.trail_name
      cred           = param.cred
      s3_bucket_name = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_logging" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy, step.pipeline.update_cloudtrail_trail]
    pipeline   = aws.pipeline.put_s3_bucket_logging
    args = {
      cred                  = param.cred
      region                = param.region
      bucket                = param.s3_bucket_name
      bucket_logging_status = "{\"LoggingEnabled\": {\"TargetBucket\": \"${param.s3_bucket_name}\", \"TargetPrefix\": \"AWSLogs/\"}}"
    }
  }
}
