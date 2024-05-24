locals {
  cloudtrail_bucket_not_public_query = <<-EOQ
  with public_bucket_data as (
    select
      t.s3_bucket_name as name,
      b.arn,
      t.region,
      t.account_id,
      t.tags,
      t._ctx,
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
      t._ctx
  )
  select
    concat(name, ' [', region, '/', account_id, ']') as title,
    name,
    case
      when arn is null then 'arn:aws:s3:::' || name
      else arn
    end as bucket_arn,
    region,
    account_id,
    _ctx ->> 'connection_name' as cred
  from
    public_bucket_data
  where
    all_user_grants > 0
    and auth_user_grants > 0
    and anon_statements > 0;
  EOQ
}

trigger "query" "detect_and_correct_cloudtrail_bucket_not_public" {
  title         = "Detect & correct CloudTrail trails with public S3 buckets"
  description   = "Detects CloudTrail trails with public S3 buckets and runs your chosen action."
  documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_bucket_not_public_trigger.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_bucket_not_public_trigger_enabled
  schedule = var.cloudtrail_bucket_not_public_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_bucket_not_public_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_bucket_not_public
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_bucket_not_public" {
  title         = "Detect & correct CloudTrail trails with public S3 buckets"
  description   = "Detects CloudTrail trails with public S3 buckets and runs your chosen action."
  documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_bucket_not_public.md")
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
    default     = var.cloudtrail_bucket_not_public_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_bucket_not_public_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_bucket_not_public_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_bucket_not_public
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

pipeline "correct_cloudtrail_bucket_not_public" {
  title         = "Correct CloudTrail trails with public S3 buckets"
  description   = "Runs corrective action on a collection of CloudTrail trails with public S3 buckets."
  documentation = file("./cloudtrail/docs/correct_cloudtrail_bucket_not_public.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title       = string
      name        = string
      bucket_arn  = string
      region      = string
      account_id  = string
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
    default     = var.cloudtrail_bucket_not_public_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_bucket_not_public_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudTrail trails with public S3 buckets."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.name => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_bucket_not_public
    args = {
      title              = each.value.title
      name               = each.value.name
      bucket_arn         = each.value.bucket_arn
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

pipeline "correct_one_cloudtrail_bucket_not_public" {
  title         = "Correct one CloudTrail trail with public S3 bucket"
  description   = "Runs corrective action on a CloudTrail trail with a public S3 bucket."
  documentation = file("./cloudtrail/docs/correct_one_cloudtrail_bucket_not_public.md")
  tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "bucket_arn" {
    type        = string
    description = "The ARN of the S3 bucket."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "account_id" {
    type        = string
    description = "The AWS account ID."
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
    default     = var.cloudtrail_bucket_not_public_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_bucket_not_public_enabled_actions
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
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped S3 Bucket ${param.title} with public access enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_s3_bucket" = {
          label        = "Update S3 Bucket"
          value        = "update_s3_bucket"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_put_s3_bucket_public_access_block
          pipeline_args = {
            region      = param.region
            cred        = param.cred
            block_public_policy = true
            restrict_public_buckets = true
            bucket = param.name
            block_public_acls = true
            ignore_public_acls = true
          }
          success_msg = "Updated S3 Bucket access policy ${param.title}."
          error_msg   = "Error updating S3 Bucket access policy ${param.title}."
        }
      }
    }
  }
}

variable "cloudtrail_bucket_not_public_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_bucket_not_public_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_bucket_not_public_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "cloudtrail_bucket_not_public_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "update_s3_bucket"]
}