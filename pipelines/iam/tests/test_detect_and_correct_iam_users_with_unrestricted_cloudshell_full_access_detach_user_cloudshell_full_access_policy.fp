pipeline "test_detect_and_correct_iam_users_with_unrestricted_cloudshell_full_access_detach_user_cloudshell_full_access_policy" {
  title       = "Test detect and correct IAM users attached with unrestricted cloudshell full access policy"
  description = "Test detect and correct IAM users attached with unrestricted cloudshell full access pipeline."

  tags = {
    folder = "Tests"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "user_name" {
    type        = string
    description = "The name of the user."
    default     = "flowpipe-user-${uuid()}"
  }

  step "pipeline" "create_iam_user" {
    pipeline = aws.pipeline.create_iam_user
    args = {
      conn      = param.conn
      user_name = param.user_name
    }
  }

  step "container" "attach_user_policy" {
    image      = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.pipeline.create_iam_user]
    cmd = [
      "iam", "attach-user-policy",
      "--user-name", param.user_name,
      "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
    ]

    env = connection.aws[param.conn].env
  }

  step "query" "get_user_with_unrestricted_cloudshell_full_access" {
    depends_on = [step.container.attach_user_policy]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(name, ' [', account_id,  ']') as title,
        name as user_name,
        account_id,
        sp_connection_name as conn
      from
        aws_iam_user
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.user_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on      = [step.query.get_user_with_unrestricted_cloudshell_full_access]
    for_each        = { for item in step.query.get_user_with_unrestricted_cloudshell_full_access.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_unrestricted_cloudshell_full_access
    args = {
      title           = each.value.title
      user_name       = each.value.user_name
      account_id      = each.value.account_id
      conn            = connection.aws[each.value.conn]
      approvers       = []
      default_action  = "detach_policy"
      enabled_actions = ["detach_policy"]
    }
  }

  step "sleep" "sleep_70_seconds" {
    depends_on = [step.pipeline.run_detection]
    duration   = "70s"
  }

  step "query" "get_details_after_detection" {
    depends_on = [step.sleep.sleep_70_seconds]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(name, ' [', account_id,  ']') as title,
        name as user_name,
        account_id,
        sp_connection_name as conn
      from
        aws_iam_user
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.user_name}';
    EOQ
  }

  step "pipeline" "delete_iam_user" {
    depends_on = [step.query.get_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_user
    args = {
      conn      = param.conn
      user_name = param.user_name
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_user"                                   = !is_error(step.pipeline.create_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_user)}"
      "attach_user_policy"                                = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_user_policy)}"
      "get_user_with_unrestricted_cloudshell_full_access" = length(step.query.get_user_with_unrestricted_cloudshell_full_access.rows) == 1 ? "pass" : "fail: Row length is not 3"
      "get_details_after_detection"                       = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
      "delete_iam_user"                                   = !is_error(step.pipeline.delete_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_user)}"
    }
  }
}
