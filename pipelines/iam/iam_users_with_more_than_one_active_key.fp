locals {
  iam_user_with_more_than_one_active_key_query = <<-EOQ
    with users_active_key_count as (
      select
        u.arn as user_arn,
        u.name as name,
        count(*) as num
      from
        aws_iam_user as u
        left join aws_iam_access_key as k on u.name = k.user_name and u.account_id = k.account_id
      where
        k.status = 'Active'
      group by
        u.arn, u.name
    ), users_with_more_than_one_active_key as (
      select
        user_arn,
        name,
        num
      from
        users_active_key_count
      where
        num > 1
      group by
        num, user_arn, name
    ), ranked_keys as (
      select
        k.access_key_id,
        k.user_name,
        k.create_date,
        k.access_key_last_used_date,
        _ctx,
        account_id,
        row_number() over (partition by k.user_name order by k.create_date desc) as rnk
      from
        aws_iam_access_key as k
      where
        k.user_name in (select name from users_with_more_than_one_active_key)
    )
    select
			concat(access_key_id, ' [', account_id, ']') as title,
      access_key_id,
      user_name,
      access_key_last_used_date,
      create_date,
      _ctx ->> 'connection_name' as cred
    from
      ranked_keys
    where
      rnk = 2;


  ----


  select
    k.access_key_id,
    k.user_name,
    k.create_date,
    k.access_key_last_used_date,
    k.status,
    k.account_id,
    _ctx ->> 'connection_name' as cred,
    now() - k.create_date as key_age,  -- This gives an interval, including days
    EXTRACT(day from now() - k.create_date) as key_age_in_days  -- Extracts only the days part
from
    aws_iam_access_key as k
where
    k.status = 'Active'  -- Only select active keys
    and k.create_date < now() - INTERVAL '90 days'
order by
    k.create_date asc;  -- Oldest keys first

  EOQ
}

variable "iam_user_with_more_than_one_active_key_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_user_with_more_than_one_active_key_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_user_with_more_than_one_active_key_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_user_with_more_than_one_active_key_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_access_key"]
}

trigger "query" "detect_and_delete_extra_iam_user_active_keys" {
  title         = "Detect & correct Extra IAM User Active Keys"
  description   = "Detects IAM users with more than one active key and deletes the extra keys."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_user_with_more_than_one_active_key_trigger_enabled
  schedule = var.iam_user_with_more_than_one_active_key_trigger_schedule
  database = var.database
  sql      = local.iam_user_with_more_than_one_active_key_query

  capture "insert" {
    pipeline = pipeline.delete_extra_iam_user_active_keys
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.delete_extra_iam_user_active_keys
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_delete_extra_iam_user_active_keys" {
  title         = "Detect & correct Extra IAM User Active Keys"
  description   = "Detects IAM users with more than one active key and deletes the extra keys."
  tags          = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.iam_user_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_with_more_than_one_active_key_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_user_with_more_than_one_active_key_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.delete_extra_iam_user_active_keys
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

pipeline "delete_extra_iam_user_active_keys" {
  title         = "Delete Extra IAM User Active Keys"
  description   = "Runs corrective action to delete extra IAM user active keys."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title          = string
      user_name      = string
      access_key_id  = string
      cred           = string
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
    default     = var.iam_user_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_with_more_than_one_active_key_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} extra IAM user active keys."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.access_key_id => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_extra_iam_user_active_key
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      access_key_id      = each.value.access_key_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_extra_iam_user_active_key" {
  title         = "Correct one Extra IAM User Active Key"
  description   = "Runs corrective action to delete one extra IAM user active key."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The user name of the IAM user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the extra IAM user active key."
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
    default     = var.iam_user_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_with_more_than_one_active_key_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected extra IAM user active key ${param.title}."
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
            text     = "Skipped extra IAM user active key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_access_key" = {
          label        = "Delete Access Key"
          value        = "delete_access_key"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.delete_iam_access_key
          pipeline_args = {
            access_key_id = param.access_key_id
						user_name  = param.user_name
            cred          = param.cred
          }
          success_msg = "Deleted extra IAM user active key ${param.title}."
          error_msg   = "Error deleting extra IAM user active key ${param.title}."
        }
      }
    }
  }
}
