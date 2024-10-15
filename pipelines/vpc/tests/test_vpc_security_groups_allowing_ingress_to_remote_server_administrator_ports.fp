pipeline "test_detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administrator_ports" {
  title       = "Test Detect and Correct VPC Security Group Allowing Ingress to remote server administrator ports"
  description = "Test the  Revoke security group rule action for VPC Security Group rules Allowing Ingress to remote server administrator ports."
  tags = {
    type = "test"
  }

  param "region" {
    type        = string
    description = "The AWS region where the VPC and security group will be created."
    default     = "us-east-1"
  }

  param "cidr_block" {
    type        = string
    description = "The IPv4 network range for the VPC, in CIDR notation (e.g., 10.0.0.0/16)."
    default     = "10.0.0.0/24"
  }

  param "ipv6_cidr_block" {
    type        = string
    description = "The IPv6 network range for the VPC, in CIDR notation (e.g., ::/56)."
    default     = "::/56"
  }

  param "cred" {
    type        = string
    description = "The AWS credentials profile to use."
    default     = "default"
  }

  step "container" "create_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-vpc",
      "--cidr-block", param.cidr_block  # IPv4 CIDR block
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }

  step "container" "associate_ipv6_cidr_block" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "associate-vpc-cidr-block",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId,
      "--amazon-provided-ipv6-cidr-block"
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_vpc]
  }

  step "container" "create_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-security-group",
      "--group-name", "custom-security-group-both-ip",
      "--description", "Security group for custom rules with both IPv4 and IPv6",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.associate_ipv6_cidr_block]
  }

  # Allow all traffic for both IPv4 and IPv6
  step "container" "allow_all_traffic_both_ip" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--ip-permissions", jsonencode([
        {
          IpProtocol = "-1",  # All traffic
          IpRanges = [{
            CidrIp = "0.0.0.0/0",
            Description = "Allow all IPv4 traffic"
          }],
          Ipv6Ranges = [{
            CidrIpv6 = "::/0",
            Description = "Allow all IPv6 traffic"
          }]
        }
      ])
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_security_group]
  }

  # Allow SSH (port 22) for both IPv4 and IPv6
  step "container" "allow_ssh_both_ip" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--ip-permissions", jsonencode([
        {
          IpProtocol = "tcp",
          FromPort = 22,
          ToPort = 22,
          IpRanges = [{
            CidrIp = "0.0.0.0/0",
            Description = "Allow SSH over IPv4"
          }],
          Ipv6Ranges = [{
            CidrIpv6 = "::/0",
            Description = "Allow SSH over IPv6"
          }]
        }
      ])
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.allow_all_traffic_both_ip]
  }

  # Allow RDP (port 3389) for both IPv4 and IPv6
  step "container" "allow_rdp_both_ip" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "authorize-security-group-ingress",
      "--group-id", jsondecode(step.container.create_security_group.stdout).GroupId,
      "--ip-permissions", jsonencode([
        {
          IpProtocol = "tcp",
          FromPort = 3389,
          ToPort = 3389,
          IpRanges = [{
            CidrIp = "0.0.0.0/0",
            Description = "Allow RDP over IPv4"
          }],
          Ipv6Ranges = [{
            CidrIpv6 = "::/0",
            Description = "Allow RDP over IPv6"
          }]
        }
      ])
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.allow_ssh_both_ip]
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
    depends_on = [step.container.allow_rdp_both_ip]
    database = var.database
    sql      = <<-EOQ
      with bad_rules as (
        select
          group_id,
          security_group_rule_id,
          region,
          account_id,
          _ctx ->> 'connection_name' as cred    
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and (
            cidr_ipv4 = '0.0.0.0/0'
            or cidr_ipv6 = '::/0'
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
      )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        sg.group_id as group_id,
        bad_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg._ctx ->> 'connection_name' as cred
      from
        aws_vpc_security_group as sg
        left join bad_rules on bad_rules.group_id = sg.group_id
      where
        sg.group_id = '${step.transform.get_security_group_id.value}'
        and bad_rules.group_id is not null;
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_security_group_details.rows : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_remote_server_administration_ports
    args = {
      title                  = each.value.title
      group_id               = each.value.group_id
      security_group_rule_id = each.value.security_group_rule_id
      region                 = each.value.region
      cred                   = each.value.cred
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
          _ctx ->> 'connection_name' as cred    
        from
          aws_vpc_security_group_rule
        where
          type = 'ingress'
          and (
            cidr_ipv4 = '0.0.0.0/0'
            or cidr_ipv6 = '::/0'
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
      )
      select
        concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
        sg.group_id as group_id,
        bad_rules.security_group_rule_id as security_group_rule_id,
        sg.region as region,
        sg._ctx ->> 'connection_name' as cred
      from
        aws_vpc_security_group as sg
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

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
    depends_on = [step.container.allow_rdp_both_ip]
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

