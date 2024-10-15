pipeline "test_detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administrator_ports_ipv4" {
  title       = "Test Detect and Correct VPC Security Group Allowing Ingress to remote server administrator ports IPv4"
  description = "Test the  Revoke security group rule action for VPC Security Group rules Allowing Ingress to remote server administrator ports IPv4."
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
      "--group-name", "flowpipe-security-group",
      "--description", "Security group for custom rules",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_vpc]
  }

  step "container" "allow_all_traffic" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--protocol", "-1",          # Allow all traffic
      "--cidr", "0.0.0.0/0"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_security_group]
  }

  step "container" "allow_ssh" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--protocol", "tcp",
      "--port", "22",               # Allow SSH (port 22)
      "--cidr", "0.0.0.0/0"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.allow_all_traffic]
  }

  step "container" "allow_rdp" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--protocol", "tcp",
      "--port", "3389",            # Allow RDP (port 3389)
      "--cidr", "0.0.0.0/0"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.allow_ssh]
  }

  step "transform" "get_security_group_id" {
    value   = jsondecode(step.container.create_security_group.stdout).GroupId
  }

  step "sleep" "sleep_10_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "10s"
  }

  step "query" "get_security_group_details" {
    depends_on = [step.container.allow_rdp]
    database = var.database
    sql      = <<-EOQ
      with bad_rules as (
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
          and (
            cidr_ipv4 = '0.0.0.0/0'
          )
          and (
          ( ip_protocol = '-1'      -- all traffic
          and from_port is null
          )
          or (
            from_port >= 22
            and to_port <= 22
          )
          or (
            from_port >= 3389
            and to_port <= 3389
          )
      )
    ),
    security_groups as (
      select
        arn,
        region,
        account_id,
        group_id,
        sp_connection_name
      from
        aws_vpc_security_group
      order by
        group_id
    )
    select
      concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
      sg.group_id as group_id,
      bad_rules.security_group_rule_id as security_group_rule_id,
      sg.region as region,
      sg.sp_connection_name as conn
    from
      security_groups as sg
      left join bad_rules on bad_rules.group_id = sg.group_id
    where
      sg.group_id = '${step.transform.get_security_group_id.value}'
      and bad_rules.group_id is not null;
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_security_group_details.rows : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_remote_server_administration_ports_ipv4
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
      with bad_rules as (
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
          and (
            cidr_ipv4 = '0.0.0.0/0'
          )
          and (
          ( ip_protocol = '-1'      -- all traffic
          and from_port is null
          )
          or (
            from_port >= 22
            and to_port <= 22
          )
          or (
            from_port >= 3389
            and to_port <= 3389
          )
      )
    ),
    security_groups as (
      select
        arn,
        region,
        account_id,
        group_id,
        sp_connection_name
      from
        aws_vpc_security_group
      order by
        group_id
    )
    select
      concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
      sg.group_id as group_id,
      bad_rules.security_group_rule_id as security_group_rule_id,
      sg.region as region,
      sg.sp_connection_name as conn
    from
      security_groups as sg
      left join bad_rules on bad_rules.group_id = sg.group_id
    where
      sg.group_id = '${step.transform.get_security_group_id.value}'
      and bad_rules.group_id is not null;
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
    depends_on = [step.container.allow_rdp]
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

