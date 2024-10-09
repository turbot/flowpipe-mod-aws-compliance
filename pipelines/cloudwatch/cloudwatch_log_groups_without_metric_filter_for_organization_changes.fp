locals {
  cloudwatch_log_groups_without_metric_filter_for_organization_changes_query = <<-EOQ
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
        filter.filter_pattern ~ '\s*\$\.eventSource\s*=\s*organizations.amazonaws.com.+\$\.eventName\s*=\s*"?AcceptHandshake"?.+\$\.eventName\s*=\s*"?AttachPolicy"?.+\$\.eventName\s*=\s*"?CreateAccount"?.+\$\.eventName\s*=\s*"?CreateOrganizationalUnit"?.+\$\.eventName\s*=\s*"?CreatePolicy"?.+\$\.eventName\s*=\s*"?DeclineHandshake"?.+\$\.eventName\s*=\s*"?DeleteOrganization"?.+\$\.eventName\s*=\s*"?DeleteOrganizationalUnit"?.+\$\.eventName\s*=\s*"?DeletePolicy"?.+\$\.eventName\s*=\s*"?DetachPolicy"?.+\$\.eventName\s*=\s*"?DisablePolicyType"?.+\$\.eventName\s*=\s*"?EnablePolicyType"?.+\$\.eventName\s*=\s*"?InviteAccountToOrganization"?.+\$\.eventName\s*=\s*"?LeaveOrganization"?.+\$\.eventName\s*=\s*"?MoveAccount"?.+\$\.eventName\s*=\s*"?RemoveAccountFromOrganization"?.+\$\.eventName\s*=\s*"?UpdatePolicy"?.+\$\.eventName\s*=\s*"?UpdateOrganizationalUnit"?'
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
      _ctx ->> 'connection_name' as cred
    from
      aws_account as a
      left join filter_data as f on a.account_id = f.account_id
    where
      f.trail_name is null;
  EOQ
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_actions" {
  type        = list(string)
  description = " The list of enabled actions approvers can select."
  default     = ["skip", "enable_organization_changes_metric_filter"]

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_log_group_name" {
  type        = string
  description = "The name of the log group to create."
  default     = "log_group_name_43"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_region" {
  type        = string
  description = "The region to create the log group in."
  default     = "us-east-1"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_name" {
  type        = string
  description = "The name of the metric filter."
  default     = "OrganizationChangesMetric"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_role_name" {
  type        = string
  description = "The name of the IAM role to create."
  default     = "OrganizationChangesMetricRole"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_s3_bucket_name" {
  type        = string
  description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
  default     = "organizationchangesnmetrics3bucket"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_name" {
  type        = string
  description = "The name of the metric."
  default     = "OrganizationChangesMetrics"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_namespace" {
  type        = string
  description = "The namespace of the metric."
  default     = "CISBenchmark"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_queue_name" {
  type        = string
  description = "The name of the SQS queue."
  default     = "flowpipeOrganizationChanges"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_value" {
  type        = string
  description = "The value to publish to the metric."
  default     = "1"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_pattern" {
  type        = string
  description = "The filter pattern for the metric filter."
  default     = "{ ($.eventSource = \"organizations.amazonaws.com\") && (($.eventName = \"AcceptHandshake\") || ($.eventName = \"AttachPolicy\") || ($.eventName = \"CreateAccount\") || ($.eventName = \"CreateOrganizationalUnit\") || ($.eventName = \"CreatePolicy\") || ($.eventName = \"DeclineHandshake\") || ($.eventName = \"DeleteOrganization\") || ($.eventName = \"DeleteOrganizationalUnit\") || ($.eventName = \"DeletePolicy\") || ($.eventName = \"DetachPolicy\") || ($.eventName = \"DisablePolicyType\") || ($.eventName = \"EnablePolicyType\") || ($.eventName = \"InviteAccountToOrganization\") || ($.eventName = \"LeaveOrganization\") || ($.eventName = \"MoveAccount\") || ($.eventName = \"RemoveAccountFromOrganization\") || ($.eventName = \"UpdatePolicy\") || ($.eventName = \"UpdateOrganizationalUnit\")) }"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_sns_topic_name" {
  type        = string
  description = "The name of the Amazon SNS topic to create."
  default     = "organization_changes_metric_topic"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_alarm_name" {
  type        = string
  description = "The name of the CloudWatch alarm."
  default     = "organization_changes_alarm"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_trail_name" {
  type        = string
  description = "The name of the CloudTrail trail."
  default     = "OrganizationChangesMetricTrail"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

variable "cloudwatch_log_groups_without_metric_filter_for_organization_changes_protocol" {
  type        = string
  description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
  default     = "SQS"

  tags = {
    folder = "Advanced/CloudWatch"
  }
}

trigger "query" "detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes" {
  title       = "Detect & correct CloudWatch log groups without metric filter for organizationy changes"
  description = "Detect CloudWatch log groups without metric filter for organization changes and then enable organization changes metric filter."
  tags        = local.cloudwatch_common_tags

  enabled  = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trigger_enabled
  schedule = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trigger_schedule
  database = var.database
  sql      = local.cloudwatch_log_groups_without_metric_filter_for_organization_changes_query

  capture "insert" {
    pipeline = pipeline.correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes" {
  title       = "Detect & correct CloudWatch log groups without metric filter for organization changes"
  description = "Detect CloudWatch log groups without metric filter for Organization Changes and enable organization changes metric filter."
  tags        = merge(local.cloudwatch_common_tags, { type = "recommended" })

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

  param "region" {
    type        = string
    description = local.description_region
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_region
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_log_group_name
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_name
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_role_name
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trail_name
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_s3_bucket_name
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_name
  }

  param "metric_namespace" {
    type        = string
    description = "The namespace of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_namespace
  }

  param "metric_value" {
    type        = string
    description = "The value to publish to the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_value
  }

  param "filter_pattern" {
    type        = string
    description = "The filter pattern for the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_pattern
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_sns_topic_name
  }

  param "queue_name" {
    type        = string
    description = "The name of the SQS queue."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_queue_name
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_protocol
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_alarm_name
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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudwatch_log_groups_without_metric_filter_for_organization_changes_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      region             = param.region
      log_group_name     = param.log_group_name
      filter_name        = param.filter_name
      role_name          = param.role_name
      trail_name         = param.trail_name
      s3_bucket_name     = param.s3_bucket_name
      metric_name        = param.metric_name
      metric_namespace   = param.metric_namespace
      queue_name         = param.queue_name
      metric_value       = param.metric_value
      filter_pattern     = param.filter_pattern
      sns_topic_name     = param.sns_topic_name
      alarm_name         = param.alarm_name
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes" {
  title       = "Correct CloudWatch log groups without metric filter for organizationy changes"
  description = "Enable organization changes metric filter for CloudWatch log groups without metric filter for organizationy changes."
  tags        = merge(local.cloudwatch_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title = string
      cred  = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_region
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_log_group_name
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_name
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_role_name
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trail_name
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_s3_bucket_name
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_name
  }

  param "metric_namespace" {
    type        = string
    description = "The namespace of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_namespace
  }

  param "metric_value" {
    type        = string
    description = "The value to publish to the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_value
  }

  param "filter_pattern" {
    type        = string
    description = "The filter pattern for the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_pattern
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_sns_topic_name
  }

  param "queue_name" {
    type        = string
    description = "The name of the SQS queue."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_queue_name
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_protocol
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_alarm_name
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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected CloudWatch log group(s) ${length(param.items)} without metric filter for organization changes."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudwatch_log_groups_without_metric_filter_for_organization_changes
    args = {
      title              = each.value.title
      cred               = each.value.cred
      region             = param.region
      log_group_name     = param.log_group_name
      filter_name        = param.filter_name
      role_name          = param.role_name
      trail_name         = param.trail_name
      s3_bucket_name     = param.s3_bucket_name
      metric_name        = param.metric_name
      metric_namespace   = param.metric_namespace
      queue_name         = param.queue_name
      metric_value       = param.metric_value
      filter_pattern     = param.filter_pattern
      sns_topic_name     = param.sns_topic_name
      alarm_name         = param.alarm_name
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudwatch_log_groups_without_metric_filter_for_organization_changes" {
  title       = "Correct one CloudWatch log group without metric filter for organizationy changes"
  description = "Enable organization changes metric filter for a CloudWatch log group."
  tags        = merge(local.cloudwatch_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_credential
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_region
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_log_group_name
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_name
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_role_name
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trail_name
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_s3_bucket_name
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_name
  }

  param "metric_namespace" {
    type        = string
    description = "The namespace of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_namespace
  }

  param "metric_value" {
    type        = string
    description = "The value to publish to the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_value
  }

  param "filter_pattern" {
    type        = string
    description = "The filter pattern for the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_pattern
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_sns_topic_name
  }

  param "queue_name" {
    type        = string
    description = "The name of the SQS queue."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_queue_name
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_protocol
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_alarm_name
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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_default_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudWatch log group without metric filter for organization changes for account ${param.title}."
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
            text     = "Skipped CloudWatch log group without metric filter for organizationy changes for account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_organization_changes_metric_filter" = {
          label        = "Enable organization changes metric filter"
          value        = "enable_organization_changes_metric_filter"
          style        = local.style_alert
          pipeline_ref = pipeline.create_cloudwatch_metric_filter_organization_changes
          pipeline_args = {
            cred             = param.cred
            region           = param.region
            log_group_name   = param.log_group_name
            filter_name      = param.filter_name
            role_name        = param.role_name
            trail_name       = param.trail_name
            s3_bucket_name   = param.s3_bucket_name
            metric_name      = param.metric_name
            metric_namespace = param.metric_namespace
            queue_name       = param.queue_name
            metric_value     = param.metric_value
            filter_pattern   = param.filter_pattern
            sns_topic_name   = param.sns_topic_name
            alarm_name       = param.alarm_name
            assume_role_policy_document = jsonencode({
              "Version" : "2012-10-17",
              "Statement" : [
                {
                  "Effect" : "Allow",
                  "Principal" : {
                    "Service" : "cloudtrail.amazonaws.com"
                  },
                  "Action" : "sts:AssumeRole"
                }
              ]
            })
            bucket_policy = jsonencode({
              "Version" : "2012-10-17",
              "Statement" : [
                {
                  "Sid" : "AWSCloudTrailAclCheck20150319",
                  "Effect" : "Allow",
                  "Principal" : {
                    "Service" : "cloudtrail.amazonaws.com"
                  },
                  "Action" : "s3:GetBucketAcl",
                  "Resource" : "arn:aws:s3:::${param.s3_bucket_name}"
                },
                {
                  "Sid" : "AWSCloudTrailWrite20150319",
                  "Effect" : "Allow",
                  "Principal" : {
                    "Service" : "cloudtrail.amazonaws.com"
                  },
                  "Action" : "s3:PutObject",
                  "Resource" : "arn:aws:s3:::${param.s3_bucket_name}/AWSLogs/${param.title}/*",
                  "Condition" : {
                    "StringEquals" : {
                      "s3:x-amz-acl" : "bucket-owner-full-control"
                    }
                  }
                }
              ]
            })
            cloudtrail_policy_document = jsonencode({
              "Version" : "2012-10-17",
              "Statement" : [
                {
                  "Sid" : "AWSCloudTrailCreateLogStream2014110",
                  "Effect" : "Allow",
                  "Action" : [
                    "logs:CreateLogStream"
                  ],
                  "Resource" : [
                    "arn:aws:logs:*"
                  ]
                },
                {
                  "Sid" : "AWSCloudTrailPutLogEvents20141101",
                  "Effect" : "Allow",
                  "Action" : [
                    "logs:PutLogEvents"
                  ],
                  "Resource" : [
                    "arn:aws:logs:*"
                  ]
                }
              ]
            })
          }
          success_msg = "Enabled organization changes metric filter for account ${param.title}."
          error_msg   = "Error enabling organization changes metric filter for account ${param.title}."
        }
      }
    }
  }
}

pipeline "create_cloudwatch_metric_filter_organization_changes" {
  title       = "Create CloudTrail with CloudWatch Logging"
  description = "Creates a CloudTrail trail with integrated CloudWatch logging and necessary IAM roles and policies."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_region
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_log_group_name
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_name
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_role_name
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_trail_name
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_s3_bucket_name
  }

  param "acl" {
    type        = string
    description = "The access control list (ACL) for the new bucket (e.g., private, public-read)."
    optional    = true
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_name
  }

  param "metric_namespace" {
    type        = string
    description = "The namespace of the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_namespace
  }

  param "metric_value" {
    type        = string
    description = "The value to publish to the metric."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_metric_value
  }

  param "filter_pattern" {
    type        = string
    description = "The filter pattern for the metric filter."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_filter_pattern
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_sns_topic_name
  }

  param "queue_name" {
    type        = string
    description = "The name of the SQS queue."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_queue_name
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_protocol
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = var.cloudwatch_log_groups_without_metric_filter_for_organization_changes_alarm_name
  }

  param "assume_role_policy_document" {
    type        = string
    description = "The trust relationship policy document that grants an entity permission to assume the role. A JSON policy that has been converted to a string."
  }

  param "bucket_policy" {
    type        = string
    description = "The S3 bucket policy for CloudTrail."
  }

  param "cloudtrail_policy_document" {
    type        = string
    description = "The policy document that grants permissions for CloudTrail to write to CloudWatch logs."
  }

  step "container" "create_iam_role" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-role",
      "--role-name", param.role_name,
      "--assume-role-policy-document", param.assume_role_policy_document,
    ]
    env = credential.aws[param.cred].env
  }

  step "container" "create_iam_policy" {
    depends_on = [step.container.create_iam_role]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-policy",
      "--policy-name", param.role_name,
      "--policy-document", param.cloudtrail_policy_document
    ]
    env = credential.aws[param.cred].env
  }

  step "query" "get_iam_role_arn" {
    depends_on = [step.container.create_iam_role]
    database   = var.database
    sql        = <<-EOQ
      select
        arn
      from
        aws_iam_role
      where
        name = '${param.role_name}'
    EOQ
  }

  step "query" "get_iam_policy_arn" {
    depends_on = [step.container.create_iam_policy]
    database   = var.database
    sql        = <<-EOQ
      select
        arn
      from
        aws_iam_policy
      where
        name = '${param.role_name}'
    EOQ
  }

  step "container" "attach_policy_to_role" {
    depends_on = [step.query.get_iam_policy_arn]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "attach-role-policy",
      "--role-name", param.role_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn,
    ]
    env = credential.aws[param.cred].env
  }

  step "container" "create_log_group" {
    depends_on = [step.container.attach_policy_to_role]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = concat(
      ["logs", "create-log-group"],
      ["--log-group-name", param.log_group_name],
      ["--region", param.region]
    )
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_s3_bucket" {
    depends_on = [step.container.create_log_group]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = concat(
      ["s3api", "create-bucket"],
      ["--bucket", param.s3_bucket_name],
      param.acl != null ? ["--acl", param.acl] : [],
      param.region != "us-east-1" ? ["--create-bucket-configuration", "LocationConstraint=" + param.region] : []
    )
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "set_bucket_policy" {
    depends_on = [step.container.create_s3_bucket]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3api", "put-bucket-policy",
      "--bucket", param.s3_bucket_name,
      "--policy", param.bucket_policy
    ]
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "query" "get_log_group_arn" {
    depends_on = [step.container.create_log_group]
    database   = var.database
    sql        = <<-EOQ
      select
        arn
      from
        aws_cloudwatch_log_group
      where
        name = '${param.log_group_name}'
    EOQ
  }

  step "container" "create_trail" {
    depends_on = [step.query.get_log_group_arn]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = concat(
      ["cloudtrail", "create-trail"],
      ["--name", param.trail_name],
      ["--is-multi-region-trail"],
      ["--s3-bucket-name", param.s3_bucket_name],
      ["--include-global-service-events"],
      ["--cloud-watch-logs-log-group-arn", step.query.get_log_group_arn.rows[0].arn],
      ["--cloud-watch-logs-role-arn", step.query.get_iam_role_arn.rows[0].arn],
      ["--region", param.region]
    )
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "start_cloudtrail_trail_logging" {
    depends_on = [step.container.create_trail]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = ["cloudtrail", "start-logging", "--name", param.trail_name]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "set_metric_filter" {
    depends_on = [step.container.start_cloudtrail_trail_logging]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      [
        "logs", "put-metric-filter",
        "--log-group-name", param.log_group_name,
        "--filter-name", param.filter_name,
        "--metric-transformations",
        jsonencode([{
          "metricName" : param.metric_name,
          "metricNamespace" : param.metric_namespace,
          "metricValue" : param.metric_value
        }]),
        "--filter-pattern", param.filter_pattern
      ]
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_sns_topic" {
    depends_on = [step.container.set_metric_filter]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["sns", "create-topic"],
      ["--name", param.sns_topic_name],
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "query" "get_sns_topic_arn" {
    depends_on = [step.container.create_sns_topic]
    database   = var.database
    sql        = <<-EOQ
      select
        topic_arn
      from
        aws_sns_topic
      where
        title = '${param.sns_topic_name}'
        and region = '${param.region}'
    EOQ
  }

  step "container" "create_sqs_queue" {
    depends_on = [step.query.get_sns_topic_arn]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["sqs", "create-queue"],
      ["--queue-name", param.queue_name],
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "query" "get_sqs_queue_arn" {
    depends_on = [step.container.create_sqs_queue]
    database   = var.database
    sql        = <<-EOQ
      select
        queue_arn
      from
        aws_sqs_queue
      where
        title = '${param.queue_name}'
        and region = '${param.region}'
    EOQ
  }

  step "container" "subscribe_to_sns_topic" {
    depends_on = [step.query.get_sqs_queue_arn]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = ["sns", "subscribe",
      "--topic-arn", step.query.get_sns_topic_arn.rows[0].topic_arn,
      "--protocol", param.protocol,
      # notification-endpoint is mandatory with protocols
      "--notification-endpoint", step.query.get_sqs_queue_arn.rows[0].queue_arn,
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_alarm" {
    depends_on = [step.container.subscribe_to_sns_topic]
    image      = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      [
        "cloudwatch", "put-metric-alarm",
        "--alarm-name", param.alarm_name,
        "--metric-name", param.metric_name,
        "--statistic", "Sum",
        "--period", "300",
        "--threshold", "1",
        "--comparison-operator", "GreaterThanOrEqualToThreshold",
        "--evaluation-periods", "1",
        "--namespace", param.metric_namespace,
        "--alarm-actions", step.query.get_sns_topic_arn.rows[0].topic_arn
      ]
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

}