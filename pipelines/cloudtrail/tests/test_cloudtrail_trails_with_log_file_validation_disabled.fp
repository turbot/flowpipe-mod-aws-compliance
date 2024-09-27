/*
pipeline "test_detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title       = "Test Detect and Correct CloudTrail Trails With Log File Validation Disabled"
  description = "Test the create_s3_bucket pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    #description = local.cred_param_description
    default     = "default"
  }

  param "region" {
    type        = string
    #description = local.region_param_description
  }

  param "bucket" {
    type        = string
    description = "The name of the bucket."
    default     = "flowpipe-test-${uuid()}"
  }

  step "transform" "base_args" {
    output "base_args" {
      value = {
        bucket = param.bucket
        cred   = param.cred
        region = param.region
      }
    }
  }

  step "pipeline" "create_s3_bucket" {
    pipeline = pipeline.create_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  # There is no get_s3_bucket pipeline, so use list instead
  step "pipeline" "list_s3_buckets" {
    depends_on = [step.pipeline.create_s3_bucket]

    pipeline = pipeline.list_s3_buckets
    args = {
      cred   = param.cred
      region = param.region
    }

    # Ignore errors so we can always delete
    error {
      ignore = true
    }
  }

  step "pipeline" "delete_s3_bucket" {
    # Don't run before we've had a chance to list buckets
    depends_on = [step.pipeline.list_s3_buckets]

    pipeline = pipeline.delete_s3_bucket
    args     = step.transform.base_args.output.base_args
  }

  output "bucket" {
    description = "Bucket name used in the test."
    value       = param.bucket
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_s3_bucket" = !is_error(step.pipeline.create_s3_bucket) ? "pass" : "fail: ${error_message(step.pipeline.create_s3_bucket)}"
      "list_s3_buckets"  = !is_error(step.pipeline.list_s3_buckets) && length([for bucket in try(step.pipeline.list_s3_buckets.output.buckets, []) : bucket if bucket.Name == param.bucket]) > 0 ? "pass" : "fail: ${error_message(step.pipeline.list_s3_buckets)}"
      "delete_s3_bucket" = !is_error(step.pipeline.delete_s3_bucket) ? "pass" : "fail: ${error_message(step.pipeline.create_s3_bucket)}"
    }
  }

}


/*
locals {
  cloudtrail_trail_with_log_validation_disabled_query = <<-EOQ
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    _ctx ->> 'connection_name' as cred
  from
    aws_cloudtrail_trail
  where
    not log_file_validation_enabled
    and region = home_region;
  EOQ
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & correct CloudTrail trails with log file validation disabled"
  description   = "Detects CloudTrail trails without log file validation enabled and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_trail_validation_enabled_trigger_enabled
  schedule = var.cloudtrail_trail_validation_enabled_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trail_with_log_validation_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Detect & correct CloudTrail trails with log file validation disabled"
  description   = "Detects CloudTrail trails without log file validation enabled and runs your chosen action."
  // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled.md")
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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_with_log_validation_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_log_file_validation_disabled
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

pipeline "correct_cloudtrail_trails_with_log_file_validation_disabled" {
  title         = "Correct CloudTrail trails without log file validation enabled"
  description   = "Runs corrective action on a collection of CloudTrail trails without log file validation enabled."
  // documentation = file("./cloudtrail/docs/correct_cloudtrail_trails_with_log_file_validation_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title  = string
      name   = string
      region = string
      cred   = string
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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trails with log file validation disabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_log_file_validation_disabled
    args = {
      title              = each.value.title
      name               = each.value.name
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_with_log_file_validation_disabled" {
  title         = "Correct one CloudTrail trail without log file validation enabled"
  description   = "Runs corrective action on a CloudTrail trail without log file validation enabled."
  // documentation = file("./cloudtrail/docs/correct_one_cloudtrail_trail_with_log_file_validation_disabled.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    default     = var.cloudtrail_trail_validation_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_validation_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail without log file validation enabled ${param.title}."
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
            text     = "Skipped CloudTrail trail ${param.title} without log file validation enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_validation" = {
          label        = "Enable Validation"
          value        = "enable_validation"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.update_cloudtrail_trail
          pipeline_args = {
            trail_name                 = param.name
            enable_log_file_validation = true
            region                     = param.region
            cred                       = param.cred
          }
          success_msg = "Enabled log file validation for CloudTrail trail ${param.title}."
          error_msg   = "Error enabling log file validation for CloudTrail trail ${param.title}."
        }
      }
    }
  }
}

variable "cloudtrail_trail_validation_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trail_validation_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "cloudtrail_trail_validation_enabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "enable_validation"
}

variable "cloudtrail_trail_validation_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_validation"]
}
*/
