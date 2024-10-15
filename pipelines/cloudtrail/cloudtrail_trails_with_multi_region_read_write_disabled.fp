
// TODO: Check the query logic
locals {
  cloudtrail_trails_with_multi_region_read_write_disabled_query = <<-EOQ
  with event_selectors_trail_details as (
    select distinct
      name,
      account_id
    from
      aws_cloudtrail_trail,
      jsonb_array_elements(event_selectors) as e
    where
      (is_logging and is_multi_region_trail and e ->> 'ReadWriteType' = 'All')
  ),
  advanced_event_selectors_trail_details as (
    select distinct
      name,
      account_id
    from
      aws_cloudtrail_trail,
      jsonb_array_elements_text(advanced_event_selectors) as a
    where
      (is_logging and is_multi_region_trail and advanced_event_selectors is not null and (not a like '%readOnly%'))
  )
  select
    concat(a.title, ' [', a.account_id, ']') as title,
    a.account_id,
    a.sp_connection_name as conn
  from
    aws_account as a
    left join event_selectors_trail_details as d on d.account_id = a.account_id
    left join advanced_event_selectors_trail_details as ad on ad.account_id = a.account_id
  where
    ad.account_id is null and d.account_id is null;
  EOQ
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_multi_region_read_write"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_enabled_region" {
  type        = string
  description = "The AWS region where the trail and bucket will be created."
  default     = "us-east-1"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_trail_name" {
  type        = string
  description = "The name of the trail."
  default     = "test-fp-multi-region-trail"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_bucket_name" {
  type        = string
  description = "The name of the bucket."
  default     = "test-fp-multi-region-trail-bucket"

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_multi_region_read_write_disabled" {
  title       = "Detect & correct CloudTrail trails with multi-region read/write disabled"
  description = "Detect CloudTrail trails that do not have multi-region read/write enabled and then  enable multi-region read/write."
  tags        = merge(local.cloudtrail_common_tags)

  enabled  = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled
  schedule = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_multi_region_read_write_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_multi_region_read_write_disabled" {
  title       = "Detect & correct CloudTrail trails with multi-region read/write disabled"
  description = "Detect CloudTrail trails with multi-region read/write disabled and then enable multi-region read/write."
  tags        = merge(local.cloudtrail_common_tags, { recommended = "true" })

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
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_action
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_trail_name
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_bucket_name
  }

  param "region" {
    type        = string
    description = "The AWS region where the resource will be created."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_enabled_region
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_multi_region_read_write_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      items              = step.query.detect.rows
      trail_name         = param.trail_name
      bucket_name        = param.bucket_name
      region             = param.region
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_cloudtrail_trail_with_multi_region_read_write_disabled" {
  title       = "Correct CloudTrail trails with multi-region read/write disabled"
  description = "Enabled multi-region read/write for CloudTrail trails with multi-region read/write disabled."
  tags        = merge(local.cloudtrail_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title      = string
      conn       = string
      account_id = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_trail_name
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_bucket_name
  }

  param "region" {
    type        = string
    description = "The AWS region where the resource will be created."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_enabled_region
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
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} CloudTrail trail(s) with multi-region read/write disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_multi_region_read_write_disabled
    args = {
      title              = each.value.title
      account_id         = each.value.account_id
      bucket_name        = param.bucket_name
      trail_name         = param.trail_name
      region             = param.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_with_multi_region_read_write_disabled" {
  title       = "Correct one CloudTrail trail with multi-region read/write disabled"
  description = "Enabled multi-region read/write for a CloudTrail trail."
  tags        = merge(local.cloudtrail_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "account_id" {
    type        = string
    description = "The ID of the AWS account."
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_trail_name
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_bucket_name
  }

  param "region" {
    type        = string
    description = "The AWS region where the resource will be created."
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_enabled_region
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail without multi-region read/write enabled for resource ${param.title}."
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
            text     = "Skipped CloudTrail trail without multi-region read/write enabled for resource ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_multi_region_read_write" = {
          label        = "Enable multi-region read/write"
          value        = "enable_multi_region_read_write"
          style        = local.style_alert
          pipeline_ref = pipeline.create_cloudtrail_trail_enable_read_write
          pipeline_args = {
            conn           = param.conn
            trail_name     = param.trail_name
            s3_bucket_name = param.bucket_name
            account_id     = param.account_id
            region         = param.region
          }
          success_msg = "Enabled multi-region read/write for CloudTrail trail ${param.trail_name}."
          error_msg   = "Error enabling multi-region read/write for CloudTrail trail ${param.trail_name}."
        }
      }
    }
  }
}

pipeline "create_cloudtrail_trail_enable_read_write" {
  title       = "Create CloudTrail Trail with Multi-Region Read/Write Enabled"
  description = "Creates a CloudTrail trail with multi-region read/write enabled."

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
    description = local.description_connection
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

  step "pipeline" "create_s3_bucket" {
    pipeline = aws.pipeline.create_s3_bucket
    args = {
      region = "us-east-1"
      conn   = param.conn
      bucket = param.s3_bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      region = "us-east-1"
      conn   = param.conn
      bucket = param.s3_bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.s3_bucket_name}/AWSLogs/${param.account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "create_cloudtrail_trail" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      region                        = "us-east-1"
      name                          = param.trail_name
      conn                          = param.conn
      bucket_name                   = param.s3_bucket_name
      is_multi_region_trail         = true
      include_global_service_events = true
      enable_log_file_validation    = true
    }
  }

  step "pipeline" "set_event_selectors" {
    depends_on = [step.pipeline.create_cloudtrail_trail]
    pipeline   = aws.pipeline.put_cloudtrail_trail_event_selector
    args = {
      region          = "us-east-1"
      trail_name      = param.trail_name
      event_selectors = "[{\"ReadWriteType\": \"All\",\"IncludeManagementEvents\": true}]"
      conn            = param.conn
    }
  }
}

