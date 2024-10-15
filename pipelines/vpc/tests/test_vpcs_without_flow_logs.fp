pipeline "test_detect_and_correct_vpcs_without_flow_logs" {
  title       = "Test Detect and Correct VPCs without Flow logs"
  description = "Test the  Revoke security group rule action for VPC Security Group rules Allowing Ingress to remote server administrator ports."
  tags = {
    type = "test"
  }

  param "region" {
    type        = string
    description = "The AWS region where the VPC will be created."
    default     = "us-east-1"
  }

  param "cidr_block" {
    type        = string
    description = "The IPv4 network range for the VPC, in CIDR notation (e.g., 10.0.0.0/24)."
    default     = "10.0.0.0/24"
  }

  param "conn" {
    type        = string
    description = "The AWS connections profile to use."
    default     = connection.aws.default
  }

  step "container" "create_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-vpc",
      "--cidr-block", param.cidr_block
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  step "transform" "get_vpc_id" {
    value   = jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
  }

  output "vpc_id" {
    description = "VPC ID from the transform step"
    value = step.transform.get_vpc_id
  }

  step "sleep" "sleep_10_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "10s"
  }

  step "query" "get_vpc_details" {
    depends_on = [step.container.create_vpc]
    database = var.database
    sql      = <<-EOQ
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
        f.resource_id is null
        and v.vpc_id = '${step.transform.get_vpc_id.value}';
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_vpc_details.rows : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_without_flowlog
    args = {
      title                  = each.value.title
      vpc_id                 = each.value.vpc_id
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "create_flow_log"
      enabled_actions        = ["create_flow_log"]
    }
  }

  step "sleep" "sleep_20_seconds" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "20s"
  }

  step "query" "get_vpc_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database = var.database
    sql      = <<-EOQ
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
        f.resource_id is null
        and v.vpc_id = '${step.transform.get_vpc_id.value}';
    EOQ
  }

  output "query_output_result_after_remediation" {
    value = step.query.get_vpc_details_after_remediation
  }

  output "result" {
    description = "Result of action verification."
    value       = length(step.query.get_vpc_details_after_remediation.rows) == 0 ? "pass" : "fail"
  }

  step "container" "delete_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-vpc",
      "--vpc-id", jsondecode(step.container.create_vpc.stdout).Vpc.VpcId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_vpc]
  }
}

