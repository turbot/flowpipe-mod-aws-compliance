locals {
  vpcs_without_flow_logs_query = <<-EOQ
    with vpcs as (
      select
        vpc_id,
        region,
        account_id,
        sp_connection_name as conn
      from
        aws_vpc
      order by
        vpc_id
    ),
    vpcs_with_flow_logs as (
      select
        resource_id,
        account_id,
        region
      from
        aws_vpc_flow_log
      order by
        resource_id
    )
    select
      concat(v.vpc_id, ' [', v.account_id, '/', v.region, ']') as title,
      v.vpc_id as vpc_id,
      v.region as region,
      v.conn as conn
    from
      vpcs v
      left join vpcs_with_flow_logs f on v.vpc_id = f.resource_id
    where
      f.resource_id is null;
  EOQ

  vpcs_without_flow_logs_default_action_enum  = ["notify", "skip", "create_flow_log"]
  vpcs_without_flow_logs_enabled_actions_enum = ["skip", "create_flow_log"]
}

variable "vpcs_without_flow_logs_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_role_policy" {
  type        = string
  description = "The default IAM role policy to apply"
  default     = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "test",
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  EOF

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_iam_policy" {
  type        = string
  description = "The default IAM policy to apply"
  default     = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents",
            "logs:GetLogEvents",
            "logs:FilterLogEvents"
          ],
          "Resource": "*"
        }
      ]
    }
  EOF

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_role_name" {
  type        = string
  description = "IAM role for AWS VPC Flow Log"
  default     = "FlowpipeRemediateEnableVPCFlowLogIAMRole"
  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_iam_policy_name" {
  type        = string
  description = "IAM policy for AWS VPC Flow Log"
  default     = "FlowpipeRemediateEnableVPCFlowLogIAMPolicy"
  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_cloudwatch_log_group_name" {
  type        = string
  description = "Cloud Watch Log name"
  default     = "FlowpipeRemediateEnableVPCFlowLogCloudWatchLogGroup"
  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "create_flow_log"]

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpcs_without_flow_logs_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "create_flow_log"]
  enum        = ["skip", "create_flow_log"]

  tags = {
    folder = "Advanced/VPC"
  }
}

trigger "query" "detect_and_correct_vpcs_without_flow_logs" {
  title       = "Detect & correct VPCs without flow logs"
  description = "Detect VPCs without flow logs and then skip or create flow logs."
  tags        = local.vpc_common_tags

  enabled  = var.vpcs_without_flow_logs_trigger_enabled
  schedule = var.vpcs_without_flow_logs_trigger_schedule
  database = var.database
  sql      = local.vpcs_without_flow_logs_query

  capture "insert" {
    pipeline = pipeline.correct_vpcs_without_flow_logs
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpcs_without_flow_logs" {
  title       = "Detect & correct VPCs without flow logs"
  description = "Detect VPCs without flow logs and then skip or create flow logs."
  tags        = merge(local.vpc_common_tags, { recommended = "true" })

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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpcs_without_flow_logs_default_action
    enum        = local.vpcs_without_flow_logs_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
    enum        = local.vpcs_without_flow_logs_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpcs_without_flow_logs_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpcs_without_flow_logs
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

pipeline "correct_vpcs_without_flow_logs" {
  title       = "Correct VPCs without flow logs"
  description = "Create flow logs for a collection of VPCs without flow logs."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title  = string
      vpc_id = string
      region = string
      conn   = string
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

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpcs_without_flow_logs_default_action
    enum        = local.vpcs_without_flow_logs_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
    enum        = local.vpcs_without_flow_logs_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} VPC(s) without flow log(s)."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.vpc_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_without_flowlog
    args = {
      title              = each.value.title
      vpc_id             = each.value.vpc_id
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_vpc_without_flowlog" {
  title       = "Correct one VPC without flow log"
  description = "Create a flow log for a VPC without flow log."

  tags = merge(local.vpc_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "vpc_id" {
    type        = string
    description = "The ID of the VPC."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpcs_without_flow_logs_default_action
    enum        = local.vpcs_without_flow_logs_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
    enum        = local.vpcs_without_flow_logs_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC ${param.title} without a flow log."
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
            text     = "Skipped VPC ${param.title} without flow log."
          }
          success_msg = ""
          error_msg   = ""
        },
        "create_flow_log" = {
          label        = "Create VPC flow log"
          value        = "create_flow_log"
          style        = local.style_alert
          pipeline_ref = pipeline.create_vpc_flowlog
          pipeline_args = {
            vpc_id = param.vpc_id
            region = param.region
            conn   = param.conn
          }
          success_msg = "Created Flow log ${param.title}."
          error_msg   = "Error creating Flow log ${param.title}."
        }
      }
    }
  }
}

pipeline "create_iam_role_and_policy" {
  title       = "Create IAM role and policy"
  description = "Create IAM role and policy."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  step "query" "get_iam_role" {
    database = var.database
    sql      = <<-EOQ
      select
        name,
        arn
      from
        aws_iam_role
      where
        name = '${var.vpcs_without_flow_logs_role_name}'
    EOQ
  }

  step "query" "get_iam_policy" {
    database = var.database
    sql      = <<-EOQ
      select
        name,
        arn
      from
        aws_iam_policy
      where
        name = '${var.vpcs_without_flow_logs_iam_policy_name}'
    EOQ
  }

  step "pipeline" "create_iam_role" {
    if       = length(step.query.get_iam_role.rows) == 0
    pipeline = aws.pipeline.create_iam_role
    args = {
      role_name                   = var.vpcs_without_flow_logs_role_name
      assume_role_policy_document = var.vpcs_without_flow_logs_role_policy
    }
  }

  step "pipeline" "create_iam_policy" {
    if       = length(step.query.get_iam_policy.rows) == 0
    pipeline = aws.pipeline.create_iam_policy
    args = {
      policy_name     = var.vpcs_without_flow_logs_iam_policy_name
      policy_document = var.vpcs_without_flow_logs_iam_policy
    }
  }

  step "pipeline" "attach_iam_role_policy_if_new" {
    if       = length(step.query.get_iam_policy.rows) == 0
    pipeline = aws.pipeline.attach_iam_role_policy
    args = {
      role_name  = var.vpcs_without_flow_logs_role_name
      policy_arn = step.pipeline.create_iam_policy.stdout.policy.Arn
    }
  }

  // Outputs
  output "iam_role_arn" {
    description = "IAM Role ARN output."
    value       = length(step.query.get_iam_role.rows) > 0 ? step.query.get_iam_role.rows[0].arn : step.pipeline.create_iam_role.role.Arn
  }
}

pipeline "create_cloudwatch_log_group" {
  title       = "Create Cloud Watch Log Group"
  description = "Create Cloud Watch log group."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  step "query" "get_cloudwatch_log_group_name" {
    database = var.database
    sql      = <<-EOQ
      select
        name
      from
        aws_cloudwatch_log_group
      where
        name = '${var.vpcs_without_flow_logs_iam_policy_name}'
    EOQ
  }

  step "pipeline" "create_cloudwatch_log_group" {
    if       = length(step.query.get_cloudwatch_log_group_name.rows) == 0
    pipeline = aws.pipeline.create_cloudwatch_log_group
    args = {
      log_group_name = var.vpcs_without_flow_logs_iam_policy_name
      region         = param.region
    }
  }
}

pipeline "create_vpc_flowlog" {
  title       = "Create VPC Flow Log"
  description = "Create VPC flow log."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "vpc_id" {
    type        = string
    description = "The VPC ID."
  }

  step "pipeline" "create_cloudwatch_log_group" {
    pipeline = pipeline.create_cloudwatch_log_group
    args = {
      region = param.region
      conn   = param.conn
    }
  }

  step "pipeline" "create_iam_role_and_policy" {
    pipeline = pipeline.create_iam_role_and_policy
    args = {
      conn = param.conn
    }
  }

  step "pipeline" "create_vpc_flow_logs" {
    pipeline = aws.pipeline.create_vpc_flow_logs
    args = {
      region         = param.region
      conn           = param.conn
      vpc_id         = param.vpc_id
      log_group_name = var.vpcs_without_flow_logs_iam_policy_name
      iam_role_arn   = step.pipeline.create_iam_role_and_policy.output.iam_role_arn
    }
  }
}
