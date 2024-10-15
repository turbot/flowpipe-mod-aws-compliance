pipeline "test_detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22" {
  title       = "Test Detect and Correct VPC Default Security Group Allowing Ingress to port 22 - Revoke security group rule"
  description = "Test the  Revoke security group rule action for VPC Default Security Group Allowing Ingress to port 22."
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

  param "cidr_block" {
    type        = string
    description = "The IPv4 network range for the VPC, in CIDR notation (e.g., 10.0.0.0/16)."
    default     = "10.0.0.0/24"
  }

  step "container" "create_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-vpc",
      "--cidr-block", param.cidr_block
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "create_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-security-group",
      "--group-name", "ssh-security-group",
      "--description", "Security group allowing SSH access",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_vpc]
  }

  step "container" "add_ingress_rule" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--protocol", "tcp",
      "--port", "22",
      "--cidr", "0.0.0.0/0"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_security_group]
  }

  step "transform" "get_security_group_id" {
    value   = jsondecode(step.container.create_security_group.stdout).GroupId
  }

  step "sleep" "sleep_10_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "10s"
  }

  step "query" "get_security_group_details" {
    depends_on = [step.container.add_ingress_rule]
    database = var.database
    sql      = <<-EOQ
      with ingress_rdp_rules as (
        select
          group_id,
          security_group_rule_id,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and cidr_ipv4 = '0.0.0.0/0'
          and (
            (
              ip_protocol = '-1'
              and from_port is null
            )
            or (
              from_port >= 22
              and to_port <= 22
            )
          )
      )
      select
        concat(sg.group_id, ' [', sg.region, '/', sg.account_id, ']') as title,
        sg.group_id as group_id,
        ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg.sp_connection_name as conn
      from
        aws_vpc_security_group as sg
        left join ingress_rdp_rules on ingress_rdp_rules.group_id = sg.group_id
      where
        sg.group_id = '${step.transform.get_security_group_id.value}'
        and ingress_rdp_rules.group_id is not null;
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_security_group_details.rows : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_port_22
    args = {
      title                  = each.value.title
      group_id               = each.value.group_id
      security_group_rule_id = each.value.security_group_rule_id
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "revoke_security_group_rule"
      enabled_actions        = ["revoke_security_group_rule"]
    }
  }

  step "sleep" "sleep_20_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "20s"
  }

  step "query" "get_security_group_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database = var.database
    sql      = <<-EOQ
      with ingress_rdp_rules as (
        select
          group_id,
          security_group_rule_id,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and cidr_ipv4 = '0.0.0.0/0'
          and (
            (
              ip_protocol = '-1'
              and from_port is null
            )
            or (
              from_port >= 22
              and to_port <= 22
            )
          )
      )
      select
        concat(sg.group_id, ' [', sg.region, '/', sg.account_id, ']') as title,
        sg.group_id as group_id,
        ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg.sp_connection_name as conn
      from
        aws_vpc_security_group as sg
        left join ingress_rdp_rules on ingress_rdp_rules.group_id = sg.group_id
      where
        sg.group_id = '${step.transform.get_security_group_id.value}'
        and ingress_rdp_rules.group_id is not null;  
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

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.query.get_security_group_details_after_remediation]
  }

  step "container" "delete_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-vpc",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.delete_security_group]
  }
}

