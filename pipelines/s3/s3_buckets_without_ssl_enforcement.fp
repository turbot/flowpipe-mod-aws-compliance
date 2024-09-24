locals {
  s3_buckets_without_ssl_enforcement_query = <<-EOQ
    with ssl_ok as (
      select
        distinct name,
        arn
      from
        aws_s3_bucket,
        jsonb_array_elements(policy_std -> 'Statement') as s,
        jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p,
        jsonb_array_elements_text(s -> 'Action') as a,
        jsonb_array_elements_text(s -> 'Resource') as r,
        jsonb_array_elements_text(
          s -> 'Condition' -> 'Bool' -> 'aws:securetransport'
        ) as ssl
      where
        p = '*'
        and s ->> 'Effect' = 'Deny'
        and ssl::bool = false
    )
    select
      concat(b.name, ' [', b.region, '/', b.account_id, ']') as title,
      b.name as bucket_name,
      b._ctx ->> 'connection_name' as cred,
      b.region
    from
      aws_s3_bucket as b
      left join ssl_ok as ok on ok.name = b.name
    where
      ok.name is null;
  EOQ
}

variable "s3_bucket_enforce_ssl_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_bucket_enforce_ssl_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_bucket_enforce_ssl_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_bucket_enforce_ssl_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enforce_ssl"]
}

trigger "query" "detect_and_correct_s3_buckets_without_ssl_enforcement" {
  title       = "Detect & Correct S3 Buckets Without SSL Enforcement"
  description = "Detect S3 buckets that do not enforce SSL and then skip or enforce SSL."
  // // documentation = file("./s3/docs/detect_and_correct_s3_buckets_without_ssl_enforcement_trigger.md")  

  enabled  = var.s3_bucket_enforce_ssl_trigger_enabled
  schedule = var.s3_bucket_enforce_ssl_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_without_ssl_enforcement_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_without_ssl_enforcement
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_without_ssl_enforcement" {
  title       = "Detect & Correct S3 Buckets Without SSL Enforcement"
  description = "Detect S3 buckets that do not enforce SSL and then skip or enforce SSL."
  // // documentation = file("./s3/docs/detect_and_correct_s3_buckets_without_ssl_enforcement.md")

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
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_without_ssl_enforcement_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_without_ssl_enforcement
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

pipeline "correct_s3_buckets_without_ssl_enforcement" {
  title       = "Correct S3 Buckets Without SSL Enforcement"
  description = "Executes corrective actions on S3 buckets that do not enforce SSL."
  // // documentation = file("./s3/docs/correct_s3_buckets_without_ssl_enforcement.md")
  
  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
      region      = string
      cred        = string
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
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 bucket(s) without SSL enforcement."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.bucket_name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_without_ssl_enforcement
    args = {
      title              = each.value.title
      bucket_name        = each.value.bucket_name
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

pipeline "correct_one_s3_bucket_without_ssl_enforcement" {
  title       = "Correct One S3 Bucket Without SSL Enforcement"
  description = "Enforces SSL on a single S3 bucket."
  // // documentation = file("./s3/docs/correct_one_s3_bucket_without_ssl_enforcement.md")
  
  param "title" {
    type        = string
    description = local.description_title
  }

  param "bucket_name" {
    type        = string
    description = "The name of the S3 bucket."
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
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected S3 bucket ${param.bucket_name} without SSL enforcement."
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
            send     = param.notification_level == "verbose"
            text     = "Skipped S3 bucket ${param.bucket_name} without SSL enforcement."
          }
          success_msg = "Skipped S3 bucket ${param.bucket_name} without SSL enforcement."
          error_msg   = "Error skipping S3 bucket ${param.bucket_name} without SSL enforcement."
        },
        "enforce_ssl" = {
          label        = "Enforce SSL"
          value        = "enforce_ssl"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_put_s3_bucket_policy
          pipeline_args = {
            bucket      = param.bucket_name
            region      = param.region
            cred        = param.cred
            policy      = "{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:*\", \"Resource\": [ \"arn:aws:s3:::${param.bucket_name}\", \"arn:aws:s3:::${param.bucket_name}/*\" ], \"Condition\": { \"Bool\": { \"aws:SecureTransport\": \"false\" } } } ] }"
          }
          success_msg = "Enforced SSL for S3 bucket ${param.bucket_name}."
          error_msg   = "Failed to enforce SSL for S3 bucket ${param.bucket_name}."
        }
      }
    }
  }
}