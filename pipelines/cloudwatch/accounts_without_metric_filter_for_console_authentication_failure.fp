locals {
  accounts_without_metric_filter_for_console_authentication_failure_query = <<-EOQ
    with trails as (
      select
        trail.account_id,
        trail.name as trail_name,
        trail.is_logging,
        split_part(trail.log_group_arn, ':', 7) as log_group_name
      from
        aws_cloudtrail_trail as trail,
        jsonb_array_elements(trail.event_selectors) as se
      where
        trail.is_multi_region_trail is true
        and trail.is_logging
        and se ->> 'ReadWriteType' = 'All'
        and trail.log_group_arn is not null
      order by
        trail_name
    ),
    alarms as (
      select
        metric_name,
        action_arn as topic_arn
      from
        aws_cloudwatch_alarm,
        jsonb_array_elements_text(aws_cloudwatch_alarm.alarm_actions) as action_arn
      order by
        metric_name
    ),
    topic_subscriptions as (
      select
        subscription_arn,
        topic_arn
      from
        aws_sns_topic_subscription
      order by
        subscription_arn
    ),
    metric_filters as (
      select
        filter.name as filter_name,
        filter_pattern,
        log_group_name,
        metric_transformation_name
      from
        aws_cloudwatch_log_metric_filter as filter
      where
        filter.filter_pattern ~ '\s*\$\.eventName\s*=\s*ConsoleLogin.+\$\.errorMessage\s*=\s*"Failed authentication"'
      order by
        filter_name
    ),
    filter_data as (
      select
        t.account_id,
        t.trail_name,
        f.filter_name
      from
        trails as t
      join
        metric_filters as f on f.log_group_name = t.log_group_name
      join
        alarms as alarm on alarm.metric_name = f.metric_transformation_name
      join
        topic_subscriptions as subscription on subscription.topic_arn = alarm.topic_arn
    )
    select
      a.account_id as title,
      region,
      a.account_id,
      sp_connection_name as conn
    from
      aws_account as a
      left join filter_data as f on a.account_id = f.account_id
    where
      f.trail_name is null;
  EOQ
}

variable "accounts_without_metric_filter_for_console_authentication_failure_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "accounts_without_metric_filter_for_console_authentication_failure_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

trigger "query" "detect_and_correct_accounts_without_metric_filter_for_console_authentication_failure" {
  title       = "Detect & correct accounts without metric filter for console authentication failure"
  description = "Detect accounts without a metric filter for console authentication failure."

  tags = local.cloudwatch_common_tags

  enabled  = var.accounts_without_metric_filter_for_console_authentication_failure_trigger_enabled
  schedule = var.accounts_without_metric_filter_for_console_authentication_failure_trigger_schedule
  database = var.database
  sql      = local.accounts_without_metric_filter_for_console_authentication_failure_query

  capture "insert" {
    pipeline = pipeline.correct_accounts_without_metric_filter_for_console_authentication_failure
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_accounts_without_metric_filter_for_console_authentication_failure" {
  title       = "Detect & correct accounts without metric filter for console authentication failure"
  description = "Detects accounts without a metric filter for console authentication failure."

  tags = local.cloudwatch_common_tags

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

  step "query" "detect" {
    database = param.database
    sql      = local.accounts_without_metric_filter_for_console_authentication_failure_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_accounts_without_metric_filter_for_console_authentication_failure
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_accounts_without_metric_filter_for_console_authentication_failure" {
  title       = "Correct accounts without metric filter for console authentication failure"
  description = "Send notifications for accounts without a metric filter for console authentication failure."

  tags = merge(local.cloudwatch_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title = string
      conn  = string
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

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} account(s) without metric filter for console authentication failure."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected account ${each.value.title} without metric filter for console authentication failure."
  }
}
