locals {
  cloudtrail_trail_s3_logging_enabled_query = <<-EOQ
  select
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

trigger "query" "detect_and_correct_cloudtrail_trail_s3_logging_enabled" {
  title         = "Detect & correct CloudTrail trails without S3 logging enabled"
  description   = "Detects CloudTrail trails without S3 logging enabled and runs your chosen action."
  documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_s3_logging_enabled_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_trail_s3_logging_enabled_trigger_enabled
  schedule = var.cloudtrail_trail_s3_logging_enabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trail_s3_logging_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_s3_logging_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trail_s3_logging_enabled" {
  title         = "Detect & correct CloudTrail trails without S3 logging enabled"
  description   = "Detects CloudTrail trails without S3 logging enabled and runs your chosen action."
  documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_s3_logging_enabled.md")
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
    default     = var.cloudtrail_trail_s3_logging_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_s3_logging_enabled_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_s3_logging_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_s3_logging_enabled
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

pipeline "correct_cloudtrail_trail_s3_logging_enabled" {
  title         = "Correct CloudTrail trails without S3 logging enabled"
  description   = "Runs corrective action on a collection of CloudTrail trails without S3 logging enabled."
  documentation = file("./cloudtrail/docs/correct_cloudtrail_trail_s3_logging_enabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      resource      = string
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
    default     = var.cloudtrail_trail_s3_logging_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_s3_logging_enabled_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trails without S3 logging enabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.resource => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_s3_logging_enabled
    args = {
      resource           = each.value.resource
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

pipeline "correct_one_cloudtrail_trail_s3_logging_enabled" {
  title         = "Correct one CloudTrail trail without S3 logging enabled"
  description   = "Runs corrective action on a CloudTrail trail without S3 logging enabled."
  documentation = file("./cloudtrail/docs/correct_one_cloudtrail_trail_s3_logging_enabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "resource" {
    type        = string
    description = local.description_resource
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
    default     = var.cloudtrail_trail_s3_logging_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_s3_logging_enabled_default_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail without S3 logging enabled for resource ${param.resource}."
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
            send     = param.notification_level == local.level_verbose
            text     = "Skipped CloudTrail trail without S3 logging enabled for resource ${param.resource}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_logging" = {
          label        = "Enable S3 Logging"
          value        = "enable_logging"
          style        = local.style_alert
          pipeline_ref = pipeline.enable_s3_logging_for_cloudtrail
          pipeline_args = {
            cred           = param.cred
            trail_name     = param.name
            s3_bucket_name = param.bucket_name
            region         = param.region
            account_id     = param.account_id
          }
          success_msg = "Updated CloudTrail trail ${param.resource} by enabling S3 logging."
          error_msg   = "Error updating S3 logging ${param.resource}."
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
    pipeline = local.aws_pipeline_create_s3_bucket
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = local.aws_pipeline_put_s3_bucket_policy
    args = {
      region = "us-east-1"
      cred   = param.cred
      bucket = param.s3_bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}/AWSLogs/${param.account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "update_cloudtrail_trail" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy]
    pipeline   = local.aws_pipeline_update_cloudtrail_trail
    args = {
      region         = param.region
      trail_name     = param.trail_name
      cred           = param.cred
      s3_bucket_name = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_logging" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy, step.pipeline.update_cloudtrail_trail]
    pipeline   = local.aws_pipeline_put_s3_bucket_logging
    args = {
      region         = param.region
      bucket     = param.s3_bucket_name
      bucket_logging_status = "{\"LoggingEnabled\": {\"TargetBucket\": \"${param.s3_bucket_name}\", \"TargetPrefix\": \"AWSLogs/\"}}"
      cred           = param.cred
    }
  }
}

variable "cloudtrail_trail_s3_logging_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trail_s3_logging_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_trail_s3_logging_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "cloudtrail_trail_s3_logging_enabled_default_actions" {
  type        = list(string)
  description = " The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_logging"]
}