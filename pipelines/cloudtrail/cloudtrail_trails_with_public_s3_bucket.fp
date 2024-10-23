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

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trails_with_public_s3_bucket_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trails_with_public_s3_bucket" {
  title       = "Detect & correct CloudTrail trails using public S3 bucket"
  description = "Detect CloudTrail trails with public S3 buckets."

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
  description = "Detects CloudTrail trails with public S3 bucket."

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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
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
    }
  }
}

pipeline "correct_cloudtrail_trails_with_public_s3_bucket" {
  title       = "Correct CloudTrail trails with public S3 bucket access"
  description = "Send notifications for CloudTrail trails with public S3 buckets."

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

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} CloudTrail trail(s) bucket with public access."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected CloudTrail trail bucket ${each.value.title} with public access."
  }
}
