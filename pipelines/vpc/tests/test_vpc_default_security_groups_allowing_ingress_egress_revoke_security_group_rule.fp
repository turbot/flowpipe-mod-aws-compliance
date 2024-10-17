pipeline "test_detect_and_correct_vpc_default_security_groups_allowing_ingress_egress_revoke_security_group_rule" {
  title       = "Test detect and correct VPC Default Security Group allowing ingress egress - revoke security group rule"
  description = "Test the  Revoke security group rule action for VPC Default Security Group Allowing Ingress Egress."
  tags = {
    type = "test"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = "us-east-1"
  }

  step "container" "get_default_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "describe-vpcs",
      "--filters", "Name=isDefault,Values=true"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "create_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-security-group",
      "--group-name", "default-security-group",
      "--description", "Default VPC security group",
      "--vpc-id", jsondecode(step.container.get_default_vpc.stdout).Vpcs[0].VpcId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "transform" "get_security_group_id" {
    value = jsondecode(step.container.create_security_group.stdout).GroupId
  }

  output "security_group_id" {
    description = "Security group ID from the transform step"
    value       = step.transform.get_security_group_id
  }

  step "pipeline" "create_vpc_security_rules" {
    depends_on = [step.container.create_security_group]
    pipeline   = pipeline.create_vpc_security_group_rules
    args = {
      region   = param.region
      conn     = param.conn
      group_id = step.transform.get_security_group_id.value
    }
  }

  step "sleep" "sleep_10_seconds" {
    depends_on = [step.pipeline.create_vpc_security_rules]
    duration   = "10s"
  }

  step "query" "get_security_group_details" {
    depends_on = [step.pipeline.create_vpc_security_rules]
    database   = var.database
    sql        = <<-EOQ
      with ingress_and_egress_rules as (
        select
          group_id,
          group_name,
          security_group_rule_id,
          is_egress,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_security_group_rule
        where
          group_name = 'default-security-group'
        )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        case when ingress_and_egress_rules.is_egress then 'egress' else 'ingress' end as type,
        sg.group_id as group_id,
        ingress_and_egress_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg.sp_connection_name as conn
      from
        aws_vpc_security_group as sg
        left join ingress_and_egress_rules on ingress_and_egress_rules.group_id = sg.group_id
      where
        sg.group_name   = 'default-security-group'
        and sg.group_id = '${step.transform.get_security_group_id.value}'
        and ingress_and_egress_rules.group_id is not null;
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_security_group_details.rows : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_egress
    args = {
      title                  = each.value.title
      group_id               = each.value.group_id
      security_group_rule_id = each.value.security_group_rule_id
      type                   = each.value.type
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "revoke_security_group_rule"
      enabled_actions        = ["revoke_security_group_rule"]
    }
  }

  step "sleep" "sleep_20_seconds" {
    depends_on = [step.pipeline.correct_item]
    duration   = "20s"
  }

  step "query" "get_security_group_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database   = var.database
    sql        = <<-EOQ
      with ingress_and_egress_rules as (
        select
          group_id,
          group_name,
          security_group_rule_id,
          is_egress,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_security_group_rule
        where
          group_name = 'default-security-group'
        )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        case when ingress_and_egress_rules.is_egress then 'egress' else 'ingress' end as type,
        sg.group_id as group_id,
        ingress_and_egress_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg.sp_connection_name as conn
      from
        aws_vpc_security_group as sg
        left join ingress_and_egress_rules on ingress_and_egress_rules.group_id = sg.group_id
      where
        sg.group_name   = 'default-security-group'
        and sg.group_id = '${step.transform.get_security_group_id.value}'
        and ingress_and_egress_rules.group_id is not null;
    EOQ
  }

  output "query_output_result_after_remediation" {
    value = step.query.get_security_group_details_after_remediation
  }

  output "result" {
    description = "Result of action verification."
    value       = length(step.query.get_security_group_details_after_remediation.rows) == 0 ? "pass" : "fail"
  }

  step "container" "delete_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-security-group",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId
    ]

    env        = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.query.get_security_group_details_after_remediation]
  }
}

pipeline "create_vpc_security_group_rules" {
  title       = "Create VPC Security Group Rules"
  description = "Creates ingress and egress rules for a security group."

  tags = {
    type = "internal"
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "group_id" {
    type        = string
    description = "The ID of the security group."
  }

  param "protocol" {
    type        = string
    description = "The protocol for the rule (e.g., tcp, udp, icmp)."
    default     = "tcp"
  }

  param "port_range" {
    type        = string
    description = "The port or port range for the rule (e.g., 80, 22-80)."
    // TOD: Try passing 80-80 in the port range
    default = "80"
  }

  param "cidr_block" {
    type        = string
    description = "The CIDR block for the rule (e.g., 0.0.0.0/0)."
    default     = "0.0.0.0/0"
  }

  param "egress_cidr_block" {
    type        = string
    description = "The CIDR block for egress traffic."
    default     = "0.0.0.0/0"
  }

  step "container" "create_ingress_rule" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["ec2", "authorize-security-group-ingress"],
      ["--group-id", param.group_id],
      ["--protocol", param.protocol],
      ["--port", param.port_range],
      ["--cidr", param.cidr_block]
    )

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "create_egress_rule" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["ec2", "authorize-security-group-egress"],
      ["--group-id", param.group_id],
      ["--protocol", param.protocol],
      ["--port", param.port_range],
      ["--cidr", param.egress_cidr_block]
    )

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  output "ingress_status" {
    description = "The result of creating the ingress rule."
    value       = step.container.create_ingress_rule.stdout
  }

  output "egress_status" {
    description = "The result of creating the egress rule."
    value       = step.container.create_egress_rule.stdout
  }
}
