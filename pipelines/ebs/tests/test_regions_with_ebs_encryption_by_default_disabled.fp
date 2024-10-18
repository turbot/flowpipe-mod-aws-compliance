pipeline "test_detect_and_correct_ebs_volumes_with_default_encryption_at_rest_disabled" {
  title       = "Test detect and correct EBS volume regions with default encryption at rest disabled"
  description = "Test the enable default encryption at rest for EBS volume regions for regions that have default encryption at rest disabled."

  tags = {
    folder = "Tests"
  }

  param "region" {
    type        = string
    description = "The AWS region."
    default     = "us-east-1"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  step "query" "get_ebs_volume_region_encryption_at_rest_details" {
    database = var.database
    sql      = <<-EOQ
      select
        distinct concat('[', r.account_id, '/', r.name, ']') as title,
        r.sp_connection_name as conn,
        r.name as region
      from
        aws_region as r
        left join aws_ec2_regional_settings as e on r.account_id = e.account_id and r.name = e.region
      where
        not e.default_ebs_encryption_enabled
        and r.region = '${param.region}';
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_ebs_volume_region_encryption_at_rest_details.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_region_with_ebs_encryption_by_default_disabled
    args = {
      title           = each.value.title
      region          = each.value.region
      conn            = connection.aws[each.value.conn]
      approvers       = []
      default_action  = "enable_encryption_by_default"
      enabled_actions = ["enable_encryption_by_default"]
    }
  }

  step "query" "get_ebs_volume_region_encryption_at_rest_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database   = var.database
    sql        = <<-EOQ
      select
        distinct concat('[', r.account_id, '/', r.name, ']') as title,
        r.sp_connection_name as conn,
        r.name as region
      from
        aws_region as r
        left join aws_ec2_regional_settings as e on r.account_id = e.account_id and r.name = e.region
      where
        not e.default_ebs_encryption_enabled
        and r.region = '${param.region}';
    EOQ
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_ebs_volume_region_encryption_at_rest_details_after_remediation" = length(step.query.get_ebs_volume_region_encryption_at_rest_details_after_remediation.rows) == 0 ? "pass" : "fail: Row length is not 1"
    }
  }
}
