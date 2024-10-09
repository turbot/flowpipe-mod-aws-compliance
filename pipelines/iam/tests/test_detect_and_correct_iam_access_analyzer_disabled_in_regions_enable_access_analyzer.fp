pipeline "test_detect_and_correct_iam_access_analyzer_disabled_in_regions_enable_access_analyzer" {
  title       = "Test detect and correcr IAM Access Analyzer disabled in regions"
  description = "Test detect_and_correct_iam_access_analyzer_disabled_in_region pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  step "query" "get_access_analyzer_disabled_region" {
    database = var.database
    sql = <<-EOQ
      select
        concat(r.region, ' [', r.account_id, ']') as title,
        r.region,
        r._ctx ->> 'connection_name' as cred
      from
        aws_region as r
        left join aws_accessanalyzer_analyzer as aa on r.account_id = aa.account_id and r.region = aa.region
      where
        r.opt_in_status <> 'not-opted-in'
        and aa.arn is null limit 1;
    EOQ

    throw {
      if      = length(result.rows) == 0
      message = "The access analyzer is enabled in all the regions. Exiting the pipeline."
    }
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.get_access_analyzer_disabled_region]
    for_each        = { for item in step.query.get_access_analyzer_disabled_region.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_access_analyzer_disabled_in_region
    args = {
      title                  = each.value.title
      analyzer_name          = "flowpipe-test-access-analyser"
      region                 = each.value.region
      cred                   = each.value.cred
      approvers              = []
      default_action         = "enable_access_analyzer"
      enabled_actions        = ["enable_access_analyzer"]
    }
  }

  step "query" "get_details_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(r.region, ' [', r.account_id, ']') as title,
        r.region,
        r._ctx ->> 'connection_name' as cred
      from
        aws_region as r
        left join aws_accessanalyzer_analyzer as aa on r.account_id = aa.account_id and r.region = aa.region
      where
        r.opt_in_status <> 'not-opted-in'
        and aa.arn is not null
        and r.region = '${step.query.get_access_analyzer_disabled_region.rows[0].region}';
    EOQ
  }

  step "pipeline" "delete_iam_access_analyzer" {
    depends_on = [step.query.get_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_access_analyzer
    args = {
      analyzer_name  = "flowpipe-test-access-analyser"
      region         = step.query.get_access_analyzer_disabled_region.rows[0].region
      cred           = param.cred
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_access_analyzer_disabled_region" = step.query.get_access_analyzer_disabled_region.rows
      "get_details_after_detection" = length(step.query.get_details_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_iam_access_analyzer"      = !is_error(step.pipeline.delete_iam_access_analyzer) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_access_analyzer)}"
    }
  }
}
