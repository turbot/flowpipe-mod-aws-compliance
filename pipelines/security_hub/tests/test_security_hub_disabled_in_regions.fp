pipeline "test_detect_and_correct_security_hub_disabled_in_regions" {
  title       = "Test detect and correct Security Hub disabled in regions"
  description = "Test the enable Security Hub action for regions that have security hub disabled."

  param "region" {
    type        = string
    description = "The AWS region where the VPC will be created."
    default     = "us-east-2"
  }

  param "cred" {
    type        = string
    description = "The AWS credentials profile to use."
    default     = "default"
  }

  step "query" "get_security_hub_details" {
    database   = var.database
    sql        = <<-EOQ
      select
        concat('[', r.account_id, '/', r.name, ']') as title,
        r._ctx ->> 'connection_name' as cred,
        r.name as region
      from
        aws_region as r
        left join aws_securityhub_hub as h on r.account_id = h.account_id and r.name = h.region
      where
        h.hub_arn is null
        and r.opt_in_status != 'not-opted-in'
        and r.region != any(array['af-south-1', 'eu-south-1', 'cn-north-1', 'cn-northwest-1', 'ap-northeast-3'])
        and r.region = '${param.region}';
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_security_hub_details.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_region_with_security_hub_disabled
    args = {
      title                  = each.value.title
      region                 = each.value.region
      cred                   = each.value.cred
      approvers              = []
      default_action         = "enable_without_default_standards"
      enabled_actions        = ["enable_without_default_standards"]
    }
  }

  step "query" "get_security_hub_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database   = var.database
    sql        = <<-EOQ
      select
        concat('[', r.account_id, '/', r.name, ']') as title,
        r._ctx ->> 'connection_name' as cred,
        r.name as region
      from
        aws_region as r
        left join aws_securityhub_hub as h on r.account_id = h.account_id and r.name = h.region
      where
        h.hub_arn is null
        and r.opt_in_status != 'not-opted-in'
        and r.region != any(array['af-south-1', 'eu-south-1', 'cn-north-1', 'cn-northwest-1', 'ap-northeast-3'])
        and r.region = '${param.region}';
    EOQ
  }

  output "query_output_result_after_remediation" {
    value = step.query.get_security_hub_details_after_remediation
  }

  output "result" {
    description = "Result of action verification."
    value       = length(step.query.get_security_hub_details_after_remediation.rows) == 0 ? "pass" : "fail"
  }

  step "container" "enable_security_hub" {
    depends_on  = [step.query.get_security_hub_details_after_remediation]
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "securityhub", "disable-security-hub"
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }
}

