locals {
  s3_buckets_with_public_access_enabled_query = <<-EOQ
    select
      concat(bucket.name, ' [', bucket.region, '/', bucket.account_id, ']') as title,
      bucket.region,
      bucket._ctx ->> 'connection_name' as cred,
      bucket.name as bucket_name
    from
      aws_s3_bucket as bucket,
      aws_s3_account_settings as s3account
    where
      s3account.account_id = bucket.account_id
      and not (bucket.block_public_acls or s3account.block_public_acls)
      and not (bucket.block_public_policy or s3account.block_public_policy)
      and not (bucket.ignore_public_acls or s3account.ignore_public_acls)
      and not (bucket.restrict_public_buckets or s3account.restrict_public_buckets);
  EOQ
}

variable "s3_bucket_public_access_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "s3_bucket_public_access_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "s3_bucket_public_access_enabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "s3_bucket_public_access_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "block_public_access"]
}

trigger "query" "detect_and_correct_s3_buckets_with_public_access_enabled" {
  title       = "Detect & Correct S3 Buckets With Public Access Enabled"
  description = "Detect S3 buckets with public access enabled and then skip or block public access."
  // // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_public_access_enabled_trigger.md")
  // tags          = merge(local.s3_common_tags, { class = "unused" })

  enabled  = var.s3_bucket_public_access_enabled_trigger_enabled
  schedule = var.s3_bucket_public_access_enabled_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_with_public_access_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_with_public_access_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_with_public_access_enabled" {
  title       = "Detect & Correct S3 Buckets With Public Access Enabled"
  description = "Detect S3 buckets with public access enabled and then skip or block public access."
  // // documentation = file("./s3/docs/detect_and_correct_s3_buckets_with_public_access_enabled.md")

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
    default     = var.s3_bucket_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_public_access_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_with_public_access_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_with_public_access_enabled
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

pipeline "correct_s3_buckets_with_public_access_enabled" {
  title       = "Correct S3 Buckets With Public Access Enabled"
  description = "Executes corrective actions on publicly accessible S3 buckets."
  // // documentation = file("./s3/docs/correct_s3_buckets_with_public_access_enabled.md")
  // tags          = merge(local.s3_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
      region      = string
      cred        = string
    }))
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
    default     = var.s3_bucket_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_public_access_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} S3 bucket(s) with public access."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.bucket_name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_if_publicly_accessible
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

pipeline "correct_one_s3_bucket_if_publicly_accessible" {
  title       = "Correct One S3 Bucket With Public Access Enabled"
  description = "Runs corrective action on a single S3 bucket with public access enabled."
  // // documentation = file("./s3/docs/correct_one_s3_bucket_if_publicly_accessible.md")
  // tags          = merge(local.s3_common_tags, { class = "unused" })

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
    default     = var.s3_bucket_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_public_access_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected S3 bucket ${param.title} with public access enabled."
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
            text     = "Skipped S3 bucket ${param.title} with public access."
          }
          success_msg = "Skipped S3 bucket ${param.title} with public access."
          error_msg   = "Error skipping S3 bucket ${param.title} with public access."
        },
        "block_public_access" = {
          label        = "Block public access"
          value        = "block_public_access"
          style        = local.style_alert
          pipeline_ref  = pipeline.test_put_s3_bucket_public_access_block
          pipeline_args = {
            bucket = param.bucket_name
            region = param.region
            cred   = param.cred
          }
          success_msg = "Enabled blocking of public access on S3 bucket ${param.title}."
          error_msg   = "Error disabling public access on S3 bucket ${param.title}."
        }
      }
    }
  }
}

pipeline "test_put_s3_bucket_public_access_block" {
  title       = "Put S3 Public Access Block"
  description = "Creates or modifies the PublicAccessBlock configuration for an Amazon S3 bucket."

  param "region" {
    type        = string
    description = local.description_region
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "bucket" {
    type        = string
    description = "The name of the S3 bucket."
  }

  # TODO: AWS defaults to false for all settings when not specified,
  # but we require each one to prevent accidentally turning off restrictions. Should they be required?

  param "block_public_acls" {
    type        = bool
    description = "Specifies whether Amazon S3 should block public access control lists (ACLs) for this bucket and objects in this bucket."
    default     = true
  }

  param "ignore_public_acls" {
    type        = bool
    description = "Specifies whether Amazon S3 should ignore public ACLs for this bucket and objects in this bucket."
    default     = true
  }

  param "block_public_policy" {
    type        = bool
    description = "Specifies whether Amazon S3 should block public bucket policies for this bucket."
    default     = true
  }

  param "restrict_public_buckets" {
    type        = bool
    description = "Specifies whether Amazon S3 should restrict public bucket policies for this bucket."
    default     = true
  }

  step "container" "put_s3_bucket_public_access_block" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["s3api", "put-public-access-block"],
      ["--bucket", param.bucket],
      ["--public-access-block-configuration", join(",", concat(
        param.block_public_acls != null ? ["BlockPublicAcls=${param.block_public_acls}"] : [],
        param.ignore_public_acls != null ? ["IgnorePublicAcls=${param.ignore_public_acls}"] : [],
        param.block_public_policy != null ? ["BlockPublicPolicy=${param.block_public_policy}"] : [],
        param.restrict_public_buckets != null ? ["RestrictPublicBuckets=${param.restrict_public_buckets}"] : []
      ))]
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }
}