locals {
  cloudwatch_log_groups_without_metric_filter_for_route_table_changes_query = <<-EOQ
    with filter_data as (
      select
        trail.account_id,
        trail.name as trail_name,
        trail.is_logging,
        split_part(trail.log_group_arn, ':', 7) as log_group_name,
        filter.name as filter_name,
        action_arn as topic_arn,
        alarm.metric_name,
        alarm.name as alarm_name,
        subscription.subscription_arn,
        filter.filter_pattern
      from
        aws_cloudtrail_trail as trail,
        jsonb_array_elements(trail.event_selectors) as se,
        aws_cloudwatch_log_metric_filter as filter,
        aws_cloudwatch_alarm as alarm,
        jsonb_array_elements_text(alarm.alarm_actions) as action_arn,
        aws_sns_topic_subscription as subscription
      where
        trail.is_multi_region_trail is true
        and trail.is_logging
        and se ->> 'ReadWriteType' = 'All'
        and trail.log_group_arn is not null
        and filter.log_group_name = split_part(trail.log_group_arn, ':', 7)
        and filter.filter_pattern ~ '\s*\$\.eventName\s*=\s*CreateRoute.+\$\.eventName\s*=\s*CreateRouteTable.+\$\.eventName\s*=\s*ReplaceRoute.+\$\.eventName\s*=\s*ReplaceRouteTableAssociation.+\$\.eventName\s*=\s*DeleteRouteTable.+\$\.eventName\s*=\s*DeleteRoute.+\$\.eventName\s*=\s*DisassociateRouteTable'
        and alarm.metric_name = filter.metric_transformation_name
        and subscription.topic_arn = action_arn
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
      f.trail_name is null
  EOQ
}

trigger "query" "detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes" {
  title         = "Detect & correct CloudWatch log groups without metric filter for route table changes"
  description   = "Detects CloudWatch log groups that do not have a metric filter for Route Table changes and runs your chosen action."
  // documentation = file("./cloudwatch/docs/detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes_trigger.md")
  tags          = merge(local.cloudwatch_common_tags, { class = "unused" })

  enabled  = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_trigger_enabled
  schedule = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_trigger_schedule
  database = var.database
  sql      = local.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_query

  capture "insert" {
    pipeline = pipeline.correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes" {
  title         = "Detect & correct CloudWatch log groups without metric filter for route table changes"
  description   = "Detects CloudWatch log groups that do not have a metric filter for Route Table changes and runs your chosen action."
  // documentation = file("./cloudwatch/docs/detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes.md")
  tags          = merge(local.cloudwatch_common_tags, { class = "unused", type = "featured" })

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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes
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

pipeline "correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes" {
  title         = "Correct CloudWatch log groups without metric filter for route table changes"
  description   = "Runs corrective action on a collection of CloudWatch log groups that do not have a metric filter for Route Table changes."
  // documentation = file("./cloudwatch/docs/correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes.md")
  tags          = merge(local.cloudwatch_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title      = string
      cred       = string
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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} CloudWatch log groups without metric filter for route table changes."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudwatch_log_groups_without_metric_filter_for_route_table_changes
    args = {
      title              = each.value.title
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudwatch_log_groups_without_metric_filter_for_route_table_changes" {
  title         = "Correct one CloudWatch log group without metric filter for route table changes"
  description   = "Runs corrective action on a CloudWatch log group without metric filter for route table changes."
  // documentation = file("./cloudwatch/docs/correct_one_cloudwatch_log_groups_without_metric_filter_for_route_table_changes.md")
  tags          = merge(local.cloudwatch_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_credential
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
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudWatch log group without metric filter for route table changes for account ${param.title}."
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
            text     = "Skipped CloudWatch log group without metric filter for route table changes for account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_route_table_changes_metric_filter" = {
          label        = "Enable Route Table changes Metric Filter"
          value        = "enable_route_table_changes_metric_filter"
          style        = local.style_alert
          pipeline_ref = pipeline.create_cloudwatch_metric_filter_route_table_changes
          pipeline_args = {
            cred             = param.cred
            region           = "us-east-1"
            log_group_name   = "log_group_name_34"
            filter_name      = "RouteTableChangesMetric"
            role_name        = "RouteTableChangesMetricRole"
            trail_name       = "RouteTableChangesMetricTrail"
            s3_bucket_name   = "routetablechangemetrics3bucket"
            metric_name      = "RouteTableChangeMetrics"
            metric_namespace = "CISBenchmark"
            queue_name       = "flowpipeRouteTableChanges"
            metric_value     = "1"
            filter_pattern   = "{($.eventSource = ec2.amazonaws.com) && ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }"
            sns_topic_name = "route_table_changes_metric_topic"
            protocol       = "SQS"
            alarm_name     = "route_table_changes_alarm"
            assume_role_policy_document = jsonencode({
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Principal": {
                  "Service": "cloudtrail.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
              }
            ]
          })
          bucket_policy = jsonencode({
            "Version": "2012-10-17",
            "Statement": [
              {
                "Sid": "AWSCloudTrailAclCheck20150319",
                "Effect": "Allow",
                "Principal": {
                  "Service": "cloudtrail.amazonaws.com"
                },
                "Action": "s3:GetBucketAcl",
                "Resource": "arn:aws:s3:::routetablechangemetrics3bucket"
              },
              {
                "Sid": "AWSCloudTrailWrite20150319",
                "Effect": "Allow",
                "Principal": {
                  "Service": "cloudtrail.amazonaws.com"
                },
                "Action": "s3:PutObject",
                "Resource": "arn:aws:s3:::routetablechangemetrics3bucket/AWSLogs/533793682495/*",
                "Condition": {
                  "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                  }
                }
              }
            ]
          })
          cloudtrail_policy_document = jsonencode({
            "Version": "2012-10-17",
            "Statement": [
              {
                "Sid": "AWSCloudTrailCreateLogStream2014110",
                "Effect": "Allow",
                "Action": [
                  "logs:CreateLogStream"
                ],
                "Resource": [
                  "arn:aws:logs:*"
                ]
              },
              {
                "Sid": "AWSCloudTrailPutLogEvents20141101",
                "Effect": "Allow",
                "Action": [
                  "logs:PutLogEvents"
                ],
                "Resource": [
                  "arn:aws:logs:*"
                ]
              }
            ]
            })
          }
          success_msg = "Enabled Route Table changes metric filter for account ${param.title}."
          error_msg   = "Error enabling Route Table changes metric filter for account ${param.title}."
        }
      }
    }
  }
}


variable "cloudwatch_log_groups_without_metric_filter_for_route_table_changes_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudwatch_log_groups_without_metric_filter_for_route_table_changes_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "cloudwatch_log_groups_without_metric_filter_for_route_table_changes_default_actions" {
  type        = list(string)
  description = " The list of enabled actions approvers can select."
  default     = ["skip", "enable_route_table_changes_metric_filter"]
}


pipeline "create_cloudwatch_metric_filter_route_table_changes" {
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
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = "log_group_name_34"
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = "RouteTableChangesMetric"
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = "RouteTableChangesMetricRole"
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = "RouteTableChangesMetricTrail"
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = "routetablechangemetrics3bucket"
  }

  param "acl" {
    type        = string
    description = "The access control list (ACL) for the new bucket (e.g., private, public-read)."
    optional    = true
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = "RouteTableChangeMetrics"
  }

  param "metric_namespace" {
    type        = string
    description = "The namespace of the metric."
    default     = "CISBenchmark"
  }

  param "metric_value" {
    type        = string
    description = "The value to publish to the metric."
    default     = "1"
  }

  param "filter_pattern" {
    type        = string
    description = "The filter pattern for the metric filter."
    default     = "{($.eventSource = ec2.amazonaws.com) && ($.eventName = CreateRoute) || ($.eventName = CreateRouteTable) || ($.eventName = ReplaceRoute) || ($.eventName = ReplaceRouteTableAssociation) || ($.eventName = DeleteRouteTable) || ($.eventName = DeleteRoute) || ($.eventName = DisassociateRouteTable) }"
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = "route_table_changes_metric_topic"
  }

  param "queue_name" {
    type        = string
    description = "The name of the SQS queue."
    default     = "flowpipeRouteTableChanges"
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = "SQS"
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = "route_table_changes_alarm"
  }

  param "assume_role_policy_document" {
    type        = string
    description = "The trust relationship policy document that grants an entity permission to assume the role. A JSON policy that has been converted to a string."
    default = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "cloudtrail.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  param "bucket_policy" {
    type        = string
    description = "The S3 bucket policy for CloudTrail."
    default = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AWSCloudTrailAclCheck20150319",
          "Effect": "Allow",
          "Principal": {
            "Service": "cloudtrail.amazonaws.com"
          },
          "Action": "s3:GetBucketAcl",
          "Resource": "arn:aws:s3:::routetablechangemetrics3bucket"
        },
        {
          "Sid": "AWSCloudTrailWrite20150319",
          "Effect": "Allow",
          "Principal": {
            "Service": "cloudtrail.amazonaws.com"
          },
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::routetablechangemetrics3bucket/AWSLogs/533793682495/*",
          "Condition": {
            "StringEquals": {
              "s3:x-amz-acl": "bucket-owner-full-control"
            }
          }
        }
      ]
    })
  }

  param "cloudtrail_policy_document" {
    type        = string
    description = "The policy document that grants permissions for CloudTrail to write to CloudWatch logs."
    default = jsonencode({
		"Version": "2012-10-17",
		"Statement": [
			{
				"Sid": "AWSCloudTrailCreateLogStream2014110",
				"Effect": "Allow",
				"Action": [
					"logs:CreateLogStream"
				],
				"Resource": [
					"arn:aws:logs:*"
				]
			},
			{
				"Sid": "AWSCloudTrailPutLogEvents20141101",
				"Effect": "Allow",
				"Action": [
					"logs:PutLogEvents"
				],
				"Resource": [
					"arn:aws:logs:*"
				]
			}
		]
    })
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
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-policy",
      "--policy-name", param.role_name,
      "--policy-document", param.cloudtrail_policy_document
    ]
    env = credential.aws[param.cred].env
  }

  step "query" "get_iam_role_arn" {
    depends_on = [step.container.create_iam_role]
    database = var.database
    sql = <<-EOQ
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
    database = var.database
    sql = <<-EOQ
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
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "attach-role-policy",
      "--role-name", param.role_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn,
      ]
    env = credential.aws[param.cred].env
  }

  step "container" "create_log_group" {
    depends_on = [step.container.attach_policy_to_role]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = concat(
      ["logs", "create-log-group"],
      ["--log-group-name", param.log_group_name],
      ["--region", param.region]
    )
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_s3_bucket" {
    depends_on = [step.container.create_log_group]
    image = "public.ecr.aws/aws-cli/aws-cli"
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
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3api", "put-bucket-policy",
      "--bucket", param.s3_bucket_name,
      "--policy", param.bucket_policy
    ]
    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "query" "get_log_group_arn" {
    depends_on = [step.container.create_log_group]
    database = var.database
    sql = <<-EOQ
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
    image = "public.ecr.aws/aws-cli/aws-cli"
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
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = ["cloudtrail", "start-logging", "--name", param.trail_name]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "set_metric_filter" {
    depends_on = [step.container.start_cloudtrail_trail_logging]
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      [
        "logs", "put-metric-filter",
        "--log-group-name", param.log_group_name,
        "--filter-name", param.filter_name,
        "--metric-transformations",
        jsonencode([{
          "metricName": param.metric_name,
          "metricNamespace": param.metric_namespace,
          "metricValue": param.metric_value
        }]),
        "--filter-pattern", param.filter_pattern
      ]
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_sns_topic" {
    depends_on = [step.container.set_metric_filter]
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["sns", "create-topic"],
      ["--name", param.sns_topic_name],
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

 step "query" "get_sns_topic_arn" {
  depends_on = [step.container.create_sns_topic]
    database = var.database
    sql = <<-EOQ
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
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["sqs", "create-queue"],
      ["--queue-name", param.queue_name],
    )

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "query" "get_sqs_queue_arn" {
    depends_on = [step.container.create_sqs_queue]
    database = var.database
    sql = <<-EOQ
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
    image = "public.ecr.aws/aws-cli/aws-cli"

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
    image = "public.ecr.aws/aws-cli/aws-cli"

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