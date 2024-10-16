variable "vpc_flow_log_role_policy" {
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

variable "vpc_flow_log_iam_policy" {
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

variable "aws_vpc_flow_log_role_name" {
  type        = string
  description = "IAM role for AWS VPC Flow Log"
  default     = "FlowpipeRemediateEnableVPCFlowLogIAMRole"
  tags = {
    folder = "Advanced/VPC"
  }
}

variable "aws_vpc_flow_log_iam_policy_name" {
  type        = string
  description = "IAM policy for AWS VPC Flow Log"
  default     = "FlowpipeRemediateEnableVPCFlowLogIAMPolicy"
  tags = {
    folder = "Advanced/VPC"
  }
}

variable "aws_cloudwatch_log_group_name" {
  type        = string
  description = "Cloud Watch Log name"
  default     = "FlowpipeRemediateEnableVPCFlowLogCloudWatchLogGroup"
  tags = {
    folder = "Advanced/VPC"
  }
}

pipeline "create_iam_role_and_policy" {
  title = "Create IAM role and policy"
  description = "Create IAM role and policy."
  tags        = merge(local.vpc_common_tags, { type = "internal" })

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  step "query" "get_iam_role" {
    database = var.database
    sql = <<-EOQ
      select
        name,
        arn
      from
        aws_iam_role
      where
        name = '${var.aws_vpc_flow_log_role_name}'
    EOQ
  }

  step "query" "get_iam_policy" {
    database = var.database
    sql = <<-EOQ
      select
        name,
        arn
      from
        aws_iam_policy
      where
        name = '${var.aws_vpc_flow_log_iam_policy_name}'
    EOQ
  }

  step "pipeline" "create_iam_role" {
    if       = length(step.query.get_iam_role.rows) == 0
    pipeline = aws.pipeline.create_iam_role
    args = {
      role_name = var.aws_vpc_flow_log_role_name
      assume_role_policy_document = var.vpc_flow_log_role_policy
    }
  }

  step "pipeline" "create_iam_policy" {
    if       = length(step.query.get_iam_policy.rows) == 0
    pipeline = aws.pipeline.create_iam_policy
    args = {
      policy_name = var.aws_vpc_flow_log_iam_policy_name
      policy_document = var.vpc_flow_log_iam_policy
    }
  }

  step "pipeline" "attach_iam_role_policy_if_new" {
    if       = length(step.query.get_iam_policy.rows) == 0
    pipeline = aws.pipeline.attach_iam_role_policy
    args = {
      role_name = var.aws_vpc_flow_log_role_name
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
  title = "Create Cloud Watch Log Group"
  description = "Create Cloud Watch log group."
  tags        = merge(local.vpc_common_tags, { type = "internal" })

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
    sql = <<-EOQ
      select
        name
      from
        aws_cloudwatch_log_group
      where
        name = '${var.aws_cloudwatch_log_group_name}'
    EOQ
  }

  step "pipeline" "create_cloudwatch_log_group" {
    if       = length(step.query.get_cloudwatch_log_group_name.rows) == 0
    pipeline = aws.pipeline.create_cloudwatch_log_group
    args = {
      log_group_name = var.aws_cloudwatch_log_group_name
      region         = param.region
    }
  }
}

pipeline "create_vpc_flowlog" {
  title = "Create VPC Flow Log"
  description = "Create VPC flow log."
  tags        = merge(local.vpc_common_tags, { type = "internal" })

  param "region" {
    type  = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "vpc_id" {
    type  = string
    description = "The VPC ID."
  }

  step "pipeline" "create_cloudwatch_log_group" {
    pipeline = pipeline.create_cloudwatch_log_group
    args = {
      region  = param.region
      conn    = param.conn
    }
  }

  step "pipeline" "create_iam_role_and_policy" {
    pipeline = pipeline.create_iam_role_and_policy
    args  = {
      conn = param.conn
    }
  }

  step "pipeline" "create_vpc_flow_logs" {
    pipeline  = aws.pipeline.create_vpc_flow_logs
    args = {
      region = param.region
      conn   = param.conn
      vpc_id = param.vpc_id
      log_group_name = var.aws_cloudwatch_log_group_name
      iam_role_arn   = step.pipeline.create_iam_role_and_policy.output.iam_role_arn
    }
  }
}