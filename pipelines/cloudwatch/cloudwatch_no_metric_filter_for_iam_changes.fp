variable "queue_name" {
  type        = string
  description = "The name of the SQS queue."
  default     = "flowpipeIAMChangesMetricQueue"
}

variable "database" {
  type        = string
  description = "Steampipe database connection string."
  default     = "postgres://steampipe@localhost:9193/steampipe"
}

pipeline "create_cloudtrail_with_logging" {
  title       = "Create CloudTrail with CloudWatch Logging"
  description = "Creates a CloudTrail trail with integrated CloudWatch logging and necessary IAM roles and policies."

  param "cred" {
    type        = string
    description = local.cred_param_description
    default     = "default"
  }

  param "region" {
    type        = string
    description = local.region_param_description
  }

  param "log_group_name" {
    type        = string
    description = "The name of the log group to create."
    default     = "IAMChangesMetricLogGroupName"
  }

  param "filter_name" {
    type        = string
    description = "The name of the metric filter."
    default     = "IAMChangesMetric"
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role to create."
    default     = "IAMChangesMetricrRole"
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = "IAMChangesMetricTrail"
  }

  param "s3_bucket_name" {
    type        = string
    description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
    default     = "iamchangemetrics3bucket"
  }

  param "log_group_arn" {
    type        = string
    description = "The ARN of the CloudWatch log group."
    default     = "arn:aws:logs:us-east-1:533793682495:log-group:IAMChangesMetricLogGroupName:*"
  }

  param "role_arn" {
    type        = string
    description = "The ARN of the IAM role."
    default     = "arn:aws:iam::533793682495:role/role_26"
  }

  param "policy_arn" {
    type        = string
    description = "The ARN of the IAM role."
    default     = "arn:aws:iam::533793682495:policy/role_26"
  }

  param "acl" {
    type        = string
    description = "The access control list (ACL) for the new bucket (e.g., private, public-read)."
    optional    = true
  }

  param "metric_name" {
    type        = string
    description = "The name of the metric."
    default     = "IAMChangeMetric"
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
    default     = "{($.eventName=DeleteGroupPolicy)||($.eventName=DeleteRolePolicy)||($.eventName=DeleteUserPolicy)||($.eventName=PutGroupPolicy)||($.eventName=PutRolePolicy)||($.eventName=PutUserPolicy)||($.eventName=CreatePolicy)||($.eventName=DeletePolicy)||($.eventName=CreatePolicyVersion)||($.eventName=DeletePolicyVersion)||($.eventName=AttachRolePolicy)||($.eventName=DetachRolePolicy)||($.eventName=AttachUserPolicy)||($.eventName=DetachUserPolicy)||($.eventName=AttachGroupPolicy)||($.eventName=DetachGroupPolicy)}"
  }

  param "sns_topic_name" {
    type        = string
    description = "The name of the Amazon SNS topic to create."
    default     = "iam_changes_metric_topic"
  }

  param "sns_topic_arn" {
    type        = string
    description = "The Amazon Resource Name (ARN) of the SNS topic to subscribe to."
    default     = "arn:aws:sns:us-east-1:533793682495:iam_changes_metric_topic"
  }

  param "protocol" {
    type        = string
    description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
    default     = "SQS"
  }

  param "alarm_name" {
    type        = string
    description = "The name of the CloudWatch alarm."
    default     = "iam_changes_alarm"
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
          "Resource": "arn:aws:s3:::iamchangemetrics3bucket"
        },
        {
          "Sid": "AWSCloudTrailWrite20150319",
          "Effect": "Allow",
          "Principal": {
            "Service": "cloudtrail.amazonaws.com"
          },
          "Action": "s3:PutObject",
          "Resource": "arn:aws:s3:::iamchangemetrics3bucket/AWSLogs/533793682495/*",
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
					"arn:aws:logs:us-east-1:533793682495:log-group:aws-cloudtrail-logs-533793682495-b6555b99:log-stream:533793682495_CloudTrail_us-east-1*"
				]
			},
			{
				"Sid": "AWSCloudTrailPutLogEvents20141101",
				"Effect": "Allow",
				"Action": [
					"logs:PutLogEvents"
				],
				"Resource": [
					"arn:aws:logs:us-east-1:533793682495:log-group:aws-cloudtrail-logs-533793682495-b6555b99:log-stream:533793682495_CloudTrail_us-east-1*"
				]
			}
		]
    })
  }

//   step "container" "create_iam_role" {
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "create-role",
//       "--role-name", param.role_name,
//       "--assume-role-policy-document", param.assume_role_policy_document,
//     ]
//     env = credential.aws[param.cred].env
//   }

//  step "container" "create_iam_policy" {
//     depends_on = [step.container.create_iam_role]
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "create-policy",
//       "--policy-name", param.role_name,
//       "--policy-document", param.cloudtrail_policy_document
//     ]
//     env = credential.aws[param.cred].env
//   }

  step "query" "get_iam_role_arn" {
    // depends_on = [step.container.create_iam_role]
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

//   step "query" "get_iam_policy_arn" {
//     depends_on = [step.container.create_iam_policy]
//     database = var.database
//     sql = <<-EOQ
//       select
//         arn
//       from
//         aws_iam_policy
//       where
//         name = '${param.role_name}'
//     EOQ
//   }

//   step "container" "attach_policy_to_role" {
//   depends_on = [step.container.create_iam_policy]
//   image = "public.ecr.aws/aws-cli/aws-cli"
//   cmd = [
//     "iam", "attach-role-policy",
//     "--role-name", param.role_name,
//     "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn,
//     ]
//   env = credential.aws[param.cred].env
//   }

//   step "container" "create_log_group" {
//     depends_on = [step.container.create_iam_role]
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = concat(
//       ["logs", "create-log-group"],
//       ["--log-group-name", param.log_group_name],
//       ["--region", param.region]
//     )
//     env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
//   }

  // step "container" "create_s3_bucket" {
  //   depends_on = [step.container.create_log_group]
  //   image = "public.ecr.aws/aws-cli/aws-cli"
  //   cmd = concat(
  //     ["s3api", "create-bucket"],
  //     ["--bucket", param.s3_bucket_name],
  //     param.acl != null ? ["--acl", param.acl] : [],
  //     param.region != "us-east-1" ? ["--create-bucket-configuration", "LocationConstraint=" + param.region] : []
  //   )
  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  // step "container" "set_bucket_policy" {
  //   depends_on = [step.container.create_s3_bucket]
  //   image = "public.ecr.aws/aws-cli/aws-cli"
  //   cmd = [
  //     "s3api", "put-bucket-policy",
  //     "--bucket", param.s3_bucket_name,
  //     "--policy", param.bucket_policy
  //   ]
  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  step "query" "get_log_group_arn" {
    // depends_on = [step.container.create_log_group]
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

  // step "container" "set_metric_filter" {
  //   image = "public.ecr.aws/aws-cli/aws-cli"

  //   cmd = concat(
  //     [
  //       "logs", "put-metric-filter",
  //       "--log-group-name", param.log_group_name,
  //       "--filter-name", param.filter_name,
  //       "--metric-transformations",
  //       jsonencode([{
  //         "metricName": param.metric_name,
  //         "metricNamespace": param.metric_namespace,
  //         "metricValue": param.metric_value
  //       }]),
  //       "--filter-pattern", param.filter_pattern
  //     ]
  //   )

  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  // step "container" "create_sns_topic" {
  //   image = "public.ecr.aws/aws-cli/aws-cli"

  //   cmd = concat(
  //     ["sns", "create-topic"],
  //     ["--name", param.sns_topic_name],
  //   )

  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  // step "container" "create_sqs_queue" {
  //   image = "public.ecr.aws/aws-cli/aws-cli"

  //   cmd = concat(
  //     ["sqs", "create-queue"],
  //     ["--queue-name", var.queue_name],
  //   )

  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  // step "query" "get_sqs_queue_arn" {
  //   database = var.database
  //   sql = <<-EOQ
  //     select
  //       queue_arn
  //     from
  //       aws_sqs_queue
  //     where
  //       title = '${var.queue_name}'
  //       and region = '${param.region}'
  //   EOQ
  // }

  // step "container" "subscribe_to_sns_topic" {
  //   depends_on = [step.query.get_sqs_queue_arn]
  //   image = "public.ecr.aws/aws-cli/aws-cli"

  //   cmd = ["sns", "subscribe",
  //     "--topic-arn", param.sns_topic_arn,
  //     "--protocol", param.protocol,
  //     # notification-endpoint is mandatory with protocols
  //     "--notification-endpoint", step.query.get_sqs_queue_arn.rows[0].queue_arn,
  //   ]

  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

  // step "container" "create_alarm" {
  //   image = "public.ecr.aws/aws-cli/aws-cli"

  //   cmd = concat(
  //     [
  //       "cloudwatch", "put-metric-alarm",
  //       "--alarm-name", param.alarm_name,
  //       "--metric-name", param.metric_name,
  //       "--statistic", "Sum",
  //       "--period", "300",
  //       "--threshold", "1",
  //       "--comparison-operator", "GreaterThanOrEqualToThreshold",
  //       "--evaluation-periods", "1",
  //       "--namespace", param.metric_namespace,
  //       "--alarm-actions", param.sns_topic_arn
  //     ]
  //   )

  //   env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  // }

}