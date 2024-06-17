locals {
  cloudtrail_trail_multi_region_read_write_disabled_query = <<-EOQ
  with event_selectors_trail_details as (
    select
      distinct account_id
    from
      aws_cloudtrail_trail,
      jsonb_array_elements(event_selectors) as e
    where
      (is_logging and is_multi_region_trail and e ->> 'ReadWriteType' = 'All')
  ),
  advanced_event_selectors_trail_details as (
    select
      distinct account_id
    from
      aws_cloudtrail_trail,
      jsonb_array_elements_text(advanced_event_selectors) as a
    where
      (is_logging and is_multi_region_trail and advanced_event_selectors is not null and (not a like '%readOnly%'))
  )
  select
    a.title as resource,
    a.account_id,
    (select concat('fp-', to_char(now(), 'yyyy-mm-dd-hh24-mi-ss'))) as unique_string,
    a._ctx ->> 'connection_name' as cred
  from
    aws_account as a
    left join event_selectors_trail_details as d on d.account_id = a.account_id
    left join advanced_event_selectors_trail_details as ad on ad.account_id = a.account_id
  where
    d.account_id is null;
  EOQ
}

trigger "query" "detect_and_correct_cloudtrail_trail_multi_region_read_write_disabled" {
  title         = "Detect & correct CloudTrail trails without multi-region read/write enabled"
  description   = "Detects CloudTrail trails that do not have multi-region read/write enabled and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_multi_region_read_write_disabled_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled
  schedule = var.cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trail_multi_region_read_write_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_multi_region_read_write_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trail_multi_region_read_write_disabled" {
  title         = "Detect & correct CloudTrail trails without multi-region read/write enabled"
  description   = "Detects CloudTrail trails that do not have multi-region read/write enabled and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_multi_region_read_write_enabled.md")
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
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_multi_region_read_write_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_multi_region_read_write_disabled
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

pipeline "correct_cloudtrail_trail_multi_region_read_write_disabled" {
  title         = "Correct CloudTrail trails without multi-region read/write enabled"
  description   = "Runs corrective action on a collection of CloudTrail trails that do not have multi-region read/write enabled."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trail_multi_region_read_write_enabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      resource      = string
      cred          = string
      account_id    = string
      unique_string = string
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
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_multi_region_read_write_disabled_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trails without multi-region read/write enabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.resource => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_multi_region_read_write_disabled
    args = {
      resource           = each.value.resource
      account_id         = each.value.account_id
      unique_string      = each.value.unique_string
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_multi_region_read_write_disabled" {
  title         = "Correct one CloudTrail trail without multi-region read/write enabled"
  description   = "Runs corrective action on a CloudTrail trail without multi-region read/write enabled."
  // documentation = file("./cloudtrail/docs/correct_one_cloudtrail_trail_multi_region_read_write_enabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "resource" {
    type        = string
    description = local.description_resource
  }

  param "account_id" {
    type        = string
    description = "The ID of the AWS account."
  }

  param "unique_string" {
    type        = string
    description = "A unique string value generated by the query."
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
      detect_msg         = "Detected CloudTrail trail without multi-region read/write enabled for resource ${param.resource}."
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
            text     = "Skipped CloudTrail trail without multi-region read/write enabled for resource ${param.resource}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_read_write" = {
          label        = "Enable Multi-Region Read/Write"
          value        = "enable_read_write"
          style        = local.style_alert
          pipeline_ref = pipeline.create_cloudtrail_trail_enable_read_write
          pipeline_args = {
            cred           = param.cred
            trail_name     = param.unique_string
            s3_bucket_name = param.unique_string
            account_id     = param.account_id
            region         = "us-east-1"
          }
          success_msg = "Enabled multi-region read/write for CloudTrail trail ${param.resource}."
          error_msg   = "Error enabling multi-region read/write for CloudTrail trail ${param.resource}."
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
      region = "us-east-1"
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

  step "pipeline" "create_cloudtrail_trail" {
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy]
    pipeline   = local.aws_pipeline_create_cloudtrail_trail
    args = {
      region                        = "us-east-1"
      name                          = param.trail_name
      cred                          = param.cred
      bucket_name                   = param.s3_bucket_name
      is_multi_region_trail         = true
      include_global_service_events = true
      enable_log_file_validation    = true
    }
  }

  step "pipeline" "set_event_selectors" {
    depends_on = [step.pipeline.create_cloudtrail_trail]
    pipeline   = local.aws_pipeline_put_cloudtrail_trail_event_selectors
    args = {
      region          = "us-east-1"
      trail_name      = param.trail_name
      event_selectors = "[{\"ReadWriteType\": \"All\",\"IncludeManagementEvents\": true}]"
      cred            = param.cred
    }
  }
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trail_multi_region_read_write_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "cloudtrail_trail_multi_region_read_write_disabled_default_actions" {
  type        = list(string)
  description = " The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_read_write"]
}

