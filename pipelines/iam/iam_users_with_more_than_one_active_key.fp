locals {
  iam_users_with_more_than_one_active_key_query = <<-EOQ
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
    ), ranked_keys as (
      select
        k.access_key_id,
        k.user_name,
        k.create_date,
        k.access_key_last_used_date,
        account_id,
        row_number() over (partition by k.user_name order by k.create_date asc) as rnk,
        extract(day from (now() - k.create_date)) as access_key_age,  -- Age in days since creation
        case
          when k.access_key_last_used_date is not null then extract(day from (now() - k.access_key_last_used_date))::text
          else 'not_used'
        end as access_key_last_used_in_days, -- Days since last used, or "not_used"
        case
          when k.access_key_last_used_date is not null then k.access_key_last_used_date::text
          else 'not_used'
          end as access_key_last_used, -- Last used date, or "not_used"
        sp_connection_name as conn
      from
        aws_iam_access_key as k
      where
        k.user_name in (select name from users_with_more_than_one_active_key)
    )
    select
      concat(rk1.user_name, ' [', rk1.account_id, ']') as title,
      rk1.user_name,
      rk1.account_id,
      rk1.access_key_id as access_key_id_1,
      rk1.access_key_last_used as access_key_1_last_used_date,
      (rk1.access_key_age)::text as access_key_1_age,
      rk1.access_key_last_used_in_days as access_key_1_last_used_in_days,
      rk2.access_key_id as access_key_id_2,
      rk2.access_key_last_used as access_key_2_last_used_date,
      (rk2.access_key_age)::text as access_key_2_age,
      rk2.access_key_last_used_in_days as access_key_2_last_used_in_days,
      rk1.account_id,
      rk1.conn
    from
      ranked_keys rk1
      left join ranked_keys rk2 on rk1.user_name = rk2.user_name and rk2.rnk = 2
    where
      rk1.rnk = 1
    order by
      rk1.user_name;
  EOQ
}

variable "iam_users_with_more_than_one_active_key_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false
}

variable "iam_users_with_more_than_one_active_key_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"
}

variable "iam_users_with_more_than_one_active_key_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_with_more_than_one_active_key_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "deactivate_access_key_1", "deactivate_access_key_2"]
}

trigger "query" "detect_and_correct_iam_users_with_more_than_one_active_key" {
  title         = "Detect & correct IAM users with more than one active key"
  description   = "Detects IAM users with more than one active key and then delete them."
  tags          = local.iam_common_tags

  enabled  = var.iam_users_with_more_than_one_active_key_trigger_enabled
  schedule = var.iam_users_with_more_than_one_active_key_trigger_schedule
  database = var.database
  sql      = local.iam_users_with_more_than_one_active_key_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_with_more_than_one_active_key
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_with_more_than_one_active_key" {
  title         = "Detect & correct IAM users with more than one active key"
  description   = "Detects IAM users with more than one active key and then delete them."
  tags          = local.iam_common_tags

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
    default     = var.iam_users_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_more_than_one_active_key_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_with_more_than_one_active_key_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_with_more_than_one_active_key
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

pipeline "correct_iam_users_with_more_than_one_active_key" {
  title         = "Correct IAM users with more than one active key"
  description   = "Runs corrective action to delete extra IAM user active keys."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title                          = string
      user_name                      = string
      access_key_id_1                = string
      access_key_1_last_used_date    = string
      access_key_1_age               = string
      access_key_1_last_used_in_days = string
      access_key_id_2                = string
      access_key_2_last_used_date    = string
      access_key_2_age               = string
      access_key_2_last_used_in_days = string
      conn                           = string
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
    default     = var.iam_users_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_more_than_one_active_key_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM user(s) with two active keys."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_more_than_one_active_key
    args = {
      title                           = each.value.title
      user_name                       = each.value.user_name
      access_key_id_1                 = each.value.access_key_id_1
      access_key_1_last_used_date     = each.value.access_key_1_last_used_date
      access_key_1_age                = each.value.access_key_1_age
      access_key_1_last_used_in_days  = each.value.access_key_1_last_used_in_days
      access_key_id_2                 = each.value.access_key_id_2
      access_key_2_last_used_date     = each.value.access_key_2_last_used_date
      access_key_2_age                = each.value.access_key_2_age
      access_key_2_last_used_in_days  = each.value.access_key_2_last_used_in_days
      conn                            = connection.aws[each.value.conn]
      notifier                        = param.notifier
      notification_level              = param.notification_level
      approvers                       = param.approvers
      default_action                  = param.default_action
      enabled_actions                 = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_user_with_more_than_one_active_key" {
  title         = "Correct one IAM user with more than one active key"
  description   = "Runs corrective action to deactivate one of the active key from two active keys for a IAM user."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The user name of the IAM user."
  }

  param "access_key_id_1" {
    type        = string
    description = "The ID of the first access key for the IAM user."
  }

  param "access_key_1_last_used_date" {
    type        = string
    description = "The date the first access key was last used, or 'not_used' if it has not been used."
  }

  param "access_key_1_age" {
    type        = string
    description = "The age of the first access key in days since it was created."
  }

  param "access_key_1_last_used_in_days" {
    type        = string
    description = "The number of days since the first access key was last used, or 'not_used' if it has not been used."
  }

  param "access_key_id_2" {
    type        = string
    description = "The ID of the second access key for the IAM user, if available."
  }

  param "access_key_2_last_used_date" {
    type        = string
    description = "The date the second access key was last used, or 'not_used' if it has not been used."
  }

  param "access_key_2_age" {
    type        = string
    description = "The age of the second access key in days since it was created."
  }

  param "access_key_2_last_used_in_days" {
    type        = string
    description = "The number of days since the second access key was last used, or 'not_used' if it has not been used."
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
    default     = var.iam_users_with_more_than_one_active_key_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_with_more_than_one_active_key_enabled_actions
  }

  step "transform" "detect_msg" {
    value = <<-EOT
      ${param.access_key_1_last_used_in_days != "not_used" ?
      format("Detected IAM user %s with access key 1 %s (last used %s days ago on %s with the key currently aged %s days(s))", param.title, param.access_key_id_1, param.access_key_1_last_used_in_days, param.access_key_1_last_used_date, param.access_key_1_age) :
      format("Detected IAM user %s with access key 1 %s (never used with the key currently aged %s days(s))", param.title, param.access_key_id_1, param.access_key_1_age)}

      ${param.access_key_2_last_used_in_days != "not_used" ?
      format(" and access key 2 %s (last used %s days ago on %s with the key currently aged %s days(s)).", param.access_key_id_2, param.access_key_2_last_used_in_days, param.access_key_2_last_used_date, param.access_key_2_age) :
      format(" and access key 2 %s (never used with the key currently aged %s day(s)).", param.access_key_id_2, param.access_key_2_age)}
    EOT
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = step.transform.detect_msg.value
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
            text     = "Skipped IAM user ${param.title} active key ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "deactivate_access_key_1" = {
          label        = "Deactivate access key 1 ${param.access_key_id_1} for user ${param.title} with the key currently aged ${param.access_key_1_age} day(s).)"
          value        = "deactivate_access_key_1"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_user_access_key
          pipeline_args = {
            access_key_id = param.access_key_id_1
            user_name     = param.user_name
            conn          = param.conn
          }
          success_msg = "Deactivated IAM user ${param.title} access key ${param.access_key_id_1}."
          error_msg   = "Error deactivating extra IAM user ${param.title} access key ${param.access_key_id_1}."
        }

        "deactivate_access_key_2" = {
          label        = "Deactivate access key 2 ${param.access_key_id_2} for user ${param.title} with the key currently aged ${param.access_key_2_age} day(s).)"
          value        = "deactivate_access_key_2"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_user_access_key
          pipeline_args = {
            access_key_id = param.access_key_id_2
            user_name     = param.user_name
            conn          = param.conn
          }
          success_msg = "Deactivated IAM user ${param.title} access key ${param.access_key_id_2}."
          error_msg   = "Error deactivating extra IAM user ${param.title} access key ${param.access_key_id_2}."
        }
      }
    }
  }
}
