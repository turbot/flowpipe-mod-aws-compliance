locals {
  cloudtrail_trails_with_s3_object_write_events_audit_disabled_query = <<-EOQ
   with s3_selectors as
    (
      select
        t.name as trail_name,
        t.is_multi_region_trail,
        bucket_selector,
        t.region,
        t.account_id,
        t._ctx
      from
        aws_cloudtrail_trail as t,
        jsonb_array_elements(t.event_selectors) as event_selector,
        jsonb_array_elements(event_selector -> 'DataResources') as data_resource,
        jsonb_array_elements_text(data_resource -> 'Values') as bucket_selector
      where
        is_multi_region_trail
        and data_resource ->> 'Type' = 'AWS::S3::Object'
        and event_selector ->> 'ReadWriteType' in
        (
          'WriteOnly',
          'All'
        ) limit 1
    )
    select
      concat(t.trail_name, ' [', t.region, '/', t.account_id, ']') as title,
      count(t.trail_name) as bucket_selector_count,
      a.account_id,
      (select concat('fp-', to_char(now(), 'yyyy-mm-dd-hh24-mi-ss'))) as resource_name,
      a._ctx ->> 'connection_name' as cred
    from
      aws_account as a
      left join s3_selectors as t on a.account_id = t.account_id
    group by
      t.trail_name, t.region, a.account_id, t.account_id, a._ctx
    having
      count(t.trail_name) = 0;
  EOQ
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled" {
  title         = "Detect & correct CloudTrail trails with S3 object write events audit disabled"
  description   = "Detects CloudTrail trails that do not have multi-region Object-level logging for write events is enabled for S3 bucket and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_trigger_enabled
  schedule = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_s3_object_write_events_audit_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled" {
  title         = "Detect & correct CloudTrail trails with S3 object write events audit disabled"
  description   = "Detects CloudTrail trails that do not have multi-region Object-level logging for write events is enabled for S3 bucket and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled.md")
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
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_s3_object_write_events_audit_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled
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

pipeline "correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled" {
  title         = "Correct CloudTrail trails with S3 object write events audit disabled"
  description   = "Runs corrective action on a collection of CloudTrail trails that do not have multi-region Object-level logging for write events is enabled for S3 bucket."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title                 = string
      bucket_selector_count = number
      resource_name         = string
      cred                  = string
      account_id            = string
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
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trails with S3 object write events audit disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.resource_name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_s3_object_write_events_audit_disabled
    args = {
      title                 = each.value.title
      bucket_selector_count = each.value.bucket_selector_count
      account_id            = each.value.account_id
      resource_name         = each.value.resource_name
      cred                  = each.value.cred
      notifier              = param.notifier
      notification_level    = param.notification_level
      approvers             = param.approvers
      default_action        = param.default_action
      enabled_actions       = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_with_s3_object_write_events_audit_disabled" {
  title         = "Correct one CloudTrail trail with S3 object write events audit disabled"
  description   = "Runs corrective action on a CloudTrail trail with S3 object write events audit disabled."
  // documentation = file("./cloudtrail/docs/correct_one_cloudtrail_trail_with_s3_object_write_events_audit_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "resource_name" {
    type        = string
    description = "The unique resource name to be created."
  }

  param "account_id" {
    type        = string
    description = "The ID of the AWS account."
  }

  param "bucket_selector_count" {
    type        = number
    description = "Indicates if remediation required or not."
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
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail ${param.title} with S3 object write events audit disabled."
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
            text     = "Skipped CloudTrail trail with S3 object write events audit disabled for ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_s3_object_write_events" = {
          label        = "Enable logging S3 Object write events"
          value        = "enable_s3_object_write_events"
          style        = local.style_alert
          pipeline_ref = pipeline.create_cloudtrail_trail_enable_s3_object_write_events
          pipeline_args = {
            bucket_selector_count = param.bucket_selector_count
            cred                  = param.cred
            resource_name         = param.resource_name
            region                = var.cloudtrail_trail_home_region_for_write_event
            account_id            = param.account_id
          }
          success_msg = "Enabled multi-region S3 object write event for CloudTrail trail ${param.title}."
          error_msg   = "Error enabling multi-region S3 object write event for CloudTrail trail ${param.title}."
        }
      }
    }
  }
}

pipeline "create_cloudtrail_trail_enable_s3_object_write_events" {
  title       = "Create CloudTrail Trail with Multi-Region Object-level logging for write events is enabled for S3 bucket"
  description = "Creates a CloudTrail trail with multi-region Object-level logging for write events is enabled for S3 bucket."

  param "region" {
    type        = string
    description = "The AWS region in which to create the CloudTrail trail."
  }

  param "bucket_selector_count" {
    type        = number
    description = "The count of buckets with read logging enabled."
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

  param "resource_name" {
    type        = string
    description = "The name of the resource to create."
  }

  step "pipeline" "create_s3_bucket" {
    if       = param.bucket_selector_count == 0
    pipeline = local.aws_pipeline_create_s3_bucket
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.resource_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    if         = param.bucket_selector_count == 0
    depends_on = [step.pipeline.create_s3_bucket]
    pipeline   = local.aws_pipeline_put_s3_bucket_policy
    args = {
      region = param.region
      cred   = param.cred
      bucket = param.resource_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.resource_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.resource_name}/AWSLogs/${param.account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n}\n]\n}"
    }
  }

  step "pipeline" "create_cloudtrail_trail" {
    if         = param.bucket_selector_count == 0
    depends_on = [step.pipeline.create_s3_bucket, step.pipeline.put_s3_bucket_policy]
    pipeline   = local.aws_pipeline_create_cloudtrail_trail
    args = {
      region                        = param.region
      name                          = param.resource_name
      cred                          = param.cred
      bucket_name                   = param.resource_name
      is_multi_region_trail         = true
      include_global_service_events = true
      enable_log_file_validation    = true
    }
  }

  step "pipeline" "set_event_selectors" {
    if         = param.bucket_selector_count == 0
    depends_on = [step.pipeline.create_cloudtrail_trail]
    pipeline   = local.aws_pipeline_put_cloudtrail_trail_event_selectors
    args = {
      region          = param.region
      trail_name      = param.resource_name
      event_selectors = "[{ \"ReadWriteType\": \"WriteOnly\", \"IncludeManagementEvents\":true, \"DataResources\": [{ \"Type\": \"AWS::S3::Object\", \"Values\": [\"arn:aws:s3:::${param.resource_name}/\"] }] }]"
      cred            = param.cred
    }
  }
}

variable "cloudtrail_trails_with_s3_object_write_events_audit_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trails_with_s3_object_write_events_audit_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "cloudtrail_trail_home_region_for_write_event" {
  type        = string
  description = "The AWS region ID to create the multi regional trail."
  default     = "us-east-1"
}

variable "cloudtrail_trails_with_s3_object_write_events_audit_disabled_default_actions" {
  type        = list(string)
  description = " The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_s3_object_write_events"]
}

