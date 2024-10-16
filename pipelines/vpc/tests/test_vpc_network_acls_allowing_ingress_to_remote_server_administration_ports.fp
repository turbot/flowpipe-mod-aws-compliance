pipeline "test_detect_and_correct_vpc_network_acls_allowing_ingress_to_remote_server_administration_ports" {
  title       = "Test Detect & correct VPC network ACLs allowing ingress to remote server administration ports - Delete network ACL entry"
  description = "Test the Delete network ACL entry action for VPC network ACLs allowing ingress to remote server administration ports."
  tags = {
    type = "test"
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = "us-east-1"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  step "container" "create_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-vpc",
      "--cidr-block", "10.0.0.0/16",
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "create_subnet" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-subnet",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId,
      "--cidr-block", "10.0.1.0/24",
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "create_nacl" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-network-acl",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId,
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "transform" "nacl_id" {
    value       = jsondecode(step.container.create_nacl.stdout).NetworkAcl.NetworkAclId
  }

  step "container" "allow_ssh_ingress" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-network-acl-entry",
      "--network-acl-id", jsondecode(step.container.create_nacl.stdout).NetworkAcl.NetworkAclId,
      "--ingress",
      "--rule-number", "100",
      "--protocol", "6",
      "--port-range", "From=22,To=22",
      "--cidr-block", "0.0.0.0/0",
      "--rule-action", "allow",
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "container" "allow_rdp_ingress" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-network-acl-entry",
      "--network-acl-id", jsondecode(step.container.create_nacl.stdout).NetworkAcl.NetworkAclId,
      "--ingress",
      "--rule-number", "110",
      "--protocol", "6",
      "--port-range", "From=3389,To=3389",
      "--cidr-block", "0.0.0.0/0",
      "--rule-action", "allow",
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "query" "get_nacl_details" {
    depends_on = [step.container.allow_rdp_ingress]
    database = var.database
    sql      = <<-EOQ
      with bad_rules as (
        select
          network_acl_id,
          att ->> 'RuleNumber' as bad_rule_number,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_network_acl,
          jsonb_array_elements(entries) as att
        where
          att ->> 'Egress' = 'false' -- as per aws egress = false indicates the ingress
          and (
            att ->> 'CidrBlock' = '0.0.0.0/0'
            or att ->> 'Ipv6CidrBlock' =  '::/0'
          )
          and att ->> 'RuleAction' = 'allow'
          and (
            (
              att ->> 'Protocol' = '-1' -- all traffic
              and att ->> 'PortRange' is null
            )
            or (
              (att -> 'PortRange' ->> 'From') :: int <= 22
              and (att -> 'PortRange' ->> 'To') :: int >= 22
              and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
            )
            or (
              (att -> 'PortRange' ->> 'From') :: int <= 3389
              and (att -> 'PortRange' ->> 'To') :: int >= 3389
              and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
          )
        )
      ),
      aws_vpc_network_acls as (
        select
          network_acl_id,
          partition,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_network_acl
        order by
          network_acl_id,
          region,
          account_id,
          conn
      )
      select
        concat(acl.network_acl_id, '/', bad_rules.bad_rule_number, ' [', acl.account_id, '/', acl.region, ']') as title,
        acl.network_acl_id as network_acl_id,
        (bad_rules.bad_rule_number)::int as rule_number,
        acl.region as region,
        acl.conn as conn
      from
        aws_vpc_network_acls as acl
        left join bad_rules on bad_rules.network_acl_id = acl.network_acl_id
      where
        bad_rules.network_acl_id is not null
        and acl.network_acl_id = '${step.transform.nacl_id.value}';
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_nacl_details.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_network_acl_allowing_ingress_to_remote_server_administration_ports
    args = {
      title                  = each.value.title
      network_acl_id         = each.value.network_acl_id
      rule_number            = each.value.rule_number
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "delete_network_acl_entry"
      enabled_actions        = ["delete_network_acl_entry"]
    }
  }

  step "sleep" "sleep_20_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "20s"
  }

  step "query" "get_nacl_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database = var.database
    sql      = <<-EOQ
      with bad_rules as (
        select
          network_acl_id,
          att ->> 'RuleNumber' as bad_rule_number,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_network_acl,
          jsonb_array_elements(entries) as att
        where
          att ->> 'Egress' = 'false' -- as per aws egress = false indicates the ingress
          and (
            att ->> 'CidrBlock' = '0.0.0.0/0'
            or att ->> 'Ipv6CidrBlock' =  '::/0'
          )
          and att ->> 'RuleAction' = 'allow'
          and (
            (
              att ->> 'Protocol' = '-1' -- all traffic
              and att ->> 'PortRange' is null
            )
            or (
              (att -> 'PortRange' ->> 'From') :: int <= 22
              and (att -> 'PortRange' ->> 'To') :: int >= 22
              and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
            )
            or (
              (att -> 'PortRange' ->> 'From') :: int <= 3389
              and (att -> 'PortRange' ->> 'To') :: int >= 3389
              and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
          )
        )
      ),
      aws_vpc_network_acls as (
        select
          network_acl_id,
          partition,
          region,
          account_id,
          sp_connection_name as conn
        from
          aws_vpc_network_acl
        order by
          network_acl_id,
          region,
          account_id,
          conn
      )
      select
        concat(acl.network_acl_id, '/', bad_rules.bad_rule_number, ' [', acl.account_id, '/', acl.region, ']') as title,
        acl.network_acl_id as network_acl_id,
        (bad_rules.bad_rule_number)::int as rule_number,
        acl.region as region,
        acl.conn as conn
      from
        aws_vpc_network_acls as acl
        left join bad_rules on bad_rules.network_acl_id = acl.network_acl_id
      where
        bad_rules.network_acl_id is not null
        and acl.network_acl_id = '${step.transform.nacl_id.value}';
    EOQ
  }

  step "container" "delete_nacl" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-network-acl",
      "--network-acl-id", jsondecode(step.container.create_nacl.stdout).NetworkAcl.NetworkAclId,
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.query.get_nacl_details_after_remediation]
  }

  step "container" "delete_subnet" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-subnet",
      "--subnet-id", jsondecode(step.container.create_subnet.stdout).Subnet.SubnetId,
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.delete_nacl]
  }

  step "container" "delete_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-vpc",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId,
      "--region", param.region
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.delete_subnet]
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_nacl_details_after_remediation" = length(step.query.get_nacl_details_after_remediation.rows) == 0 ? "pass" : "fail: Row length is not 1"
    }
  }
}

