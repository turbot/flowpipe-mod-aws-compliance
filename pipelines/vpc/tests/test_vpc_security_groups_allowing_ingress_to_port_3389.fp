pipeline "test_detect_and_correct_vpc_security_groups_allowing_ingress_to_port_3389" {
  title       = "Test Detect and Correct VPC Security Groups Allowing Ingress to port 3389 - Revoke security group rule"
  description = "Test the  Revoke security group rule action for VPC Default Security Group Allowing Ingress to port 3389."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
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

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "create_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-security-group",
      "--group-name", "ssh-security-group",
      "--description", "Security group allowing SSH access",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_vpc]
  }

  step "container" "add_ingress_rule" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--protocol", "tcp",
      "--port", "3389",
      "--cidr", "0.0.0.0/0"
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_security_group]
  }

  step "transform" "get_security_group_id" {
    value   = jsondecode(step.container.create_security_group.stdout).GroupId
  }

  output "security_group_id" {
    description = "Security group ID from the transform step"
    value = step.transform.get_security_group_id
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
          ip_protocol,
          from_port,
          to_port,
          coalesce(cidr_ipv4::text, '') as cidr_ipv4,
          coalesce(cidr_ipv6::text, '') as cidr_ipv6,
          region,
          account_id,
          _ctx ->> 'connection_name' as cred
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and (cidr_ipv4 = '0.0.0.0/0' or cidr_ipv6 = '::/0')
          and (
            (
              ip_protocol = '-1'
              and from_port is null
            )
            or (
              from_port <= 3389
              and to_port >= 3389
            )
          )
      )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        sg.group_id as group_id,
        ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        ingress_rdp_rules.ip_protocol as ip_protocol,
        ingress_rdp_rules.from_port as from_port,
        ingress_rdp_rules.to_port as to_port,
        ingress_rdp_rules.cidr_ipv4 as cidr_ipv4,
        ingress_rdp_rules.cidr_ipv6 as cidr_ipv6,
        sg._ctx ->> 'connection_name' as cred
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
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_port_3389
    args = {
      title                  = each.value.title
      group_id               = each.value.group_id
      security_group_rule_id = each.value.security_group_rule_id
      region                 = each.value.region
      cred                   = each.value.cred
      ip_protocol            = each.value.ip_protocol
      to_port                = each.value.to_port
      from_port              = each.value.from_port
      cidr_ipv4              = each.value.cidr_ipv4
      cidr_ipv6              = each.value.cidr_ipv6
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
          ip_protocol,
          from_port,
          to_port,
          coalesce(cidr_ipv4::text, '') as cidr_ipv4,
          coalesce(cidr_ipv6::text, '') as cidr_ipv6,
          region,
          account_id,
          _ctx ->> 'connection_name' as cred
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and (cidr_ipv4 = '0.0.0.0/0' or cidr_ipv6 = '::/0')
          and (
            (
              ip_protocol = '-1'
              and from_port is null
            )
            or (
              from_port <= 3389
              and to_port >= 3389
            )
          )
      )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        sg.group_id as group_id,
        ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        ingress_rdp_rules.ip_protocol as ip_protocol,
        ingress_rdp_rules.from_port as from_port,
        ingress_rdp_rules.to_port as to_port,
        ingress_rdp_rules.cidr_ipv4 as cidr_ipv4,
        ingress_rdp_rules.cidr_ipv6 as cidr_ipv6,
        sg._ctx ->> 'connection_name' as cred
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

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.query.get_security_group_details_after_remediation]
  }

  step "container" "delete_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-vpc",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.delete_security_group]
  }
}

