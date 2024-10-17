locals {
  cloudtrail_trails_with_public_s3_bucket_query = <<-EOQ
  with public_bucket_data as (
    select
      t.s3_bucket_name as name,
      b.arn,
      t.region,
      t.account_id,
      t.tags,
      t.sp_connection_name,
      count(acl_grant) filter (where acl_grant -> 'Grantee' ->> 'URI' like '%acs.amazonaws.com/groups/global/AllUsers') as all_user_grants,
      count(acl_grant) filter (where acl_grant -> 'Grantee' ->> 'URI' like '%acs.amazonaws.com/groups/global/AuthenticatedUsers') as auth_user_grants,
      count(s) filter (where s ->> 'Effect' = 'Allow' and  p = '*' ) as anon_statements
    from
      aws_cloudtrail_trail as t
      left join aws_s3_bucket as b on t.s3_bucket_name = b.name
      left join jsonb_array_elements(acl -> 'Grants') as acl_grant on true
      left join jsonb_array_elements(policy_std -> 'Statement') as s  on true
      left join jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p  on true
    group by
      t.s3_bucket_name,
      b.arn,
      t.region,
      t.account_id,
      t.tags,
      t.sp_connection_name
  )
  select
    concat(name, ' [', account_id, '/', region, ']') as title,
    name,
    region,
    account_id,
    sp_connection_name as conn
  from
    public_bucket_data
  where
    all_user_grants > 0
    and auth_user_grants > 0
    and anon_statements > 0;
  EOQ
}

variable "cloudtrail_trails_with_public_s3_bucket_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trails_with_public_s3_bucket_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "cloudtrail_trails_with_public_s3_bucket_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "cloudtrail_trails_with_public_s3_bucket_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "update_s3_bucket_block_public_access"]
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_public_s3_bucket" {
  title       = "Detect & correct CloudTrail trails using public S3 bucket"
  description = "Detect CloudTrail trails with public S3 buckets and then skip or update S3 bucket public access block."

  tags = local.cloudtrail_common_tags

  enabled  = var.cloudtrail_trails_with_public_s3_bucket_trigger_enabled
  schedule = var.cloudtrail_trails_with_public_s3_bucket_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trails_with_public_s3_bucket_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trails_with_public_s3_bucket
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trails_with_public_s3_bucket" {
  title       = "Detect & correct CloudTrail trails with public S3 bucket access"
  description = "Detect CloudTrail trails with public S3 bucket and then skip or update S3 bucket public access block."

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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.cloudtrail_trails_with_public_s3_bucket_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_public_s3_bucket_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trails_with_public_s3_bucket_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trails_with_public_s3_bucket
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

pipeline "correct_cloudtrail_trails_with_public_s3_bucket" {
  title       = "Correct CloudTrail trails with public S3 bucket access"
  description = "Runs corrective action on a collection of CloudTrail trails with public S3 buckets."

  tags = merge(local.cloudtrail_common_tags, { type = "internal" })

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
    default     = var.cloudtrail_trails_with_public_s3_bucket_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_public_s3_bucket_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} CloudTrail trail(s) with public S3 bucket."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : row.name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_with_public_s3_bucket
    args = {
      title              = each.value.title
      name               = each.value.name
      bucket_name        = each.value.name
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

pipeline "correct_one_cloudtrail_trail_with_public_s3_bucket" {
  title       = "Correct one CloudTrail trail with public S3 bucket access"
  description = "Runs corrective action on a CloudTrail trail with a public S3 bucket."

  tags = merge(local.cloudtrail_common_tags, { type = "internal" })

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
    description = "The name of the S3 bucket."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "account_id" {
    type        = string
    description = "The AWS account ID."
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
    default     = var.cloudtrail_trails_with_public_s3_bucket_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trails_with_public_s3_bucket_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail with public S3 bucket ${param.title}."
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
            text     = "Skipped S3 Bucket ${param.title} with public access enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_s3_bucket_block_public_access" = {
          label        = "Update S3 Bucket Block Public Access"
          value        = "update_s3_bucket_block_public_access"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.put_s3_bucket_public_access_block
          pipeline_args = {
            region                  = param.region
            conn                    = param.conn
            bucket                  = param.bucket_name
            block_public_policy     = true
            restrict_public_buckets = true
            block_public_acls       = true
            ignore_public_acls      = true
          }
          success_msg = "Updated S3 Bucket access policy for ${param.title}."
          error_msg   = "Error updating S3 Bucket access policy ${param.title}."
        }
      }
    }
  }
}
