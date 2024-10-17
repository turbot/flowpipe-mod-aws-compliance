pipeline "test_detect_and_correct_iam_users_with_policy_star_star_attached_detach_user_star_star_policy" {
  title       = "Test detect and correct IAM users attached with *:* policy"
  description = "Test detect and correct IAM users attached with *:* policy pipeline."

  tags = {
    type = "test"
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

  param "policy_name" {
    type        = string
    description = "The name of the policy."
    default     = "flowpipe-policy-${uuid()}"
  }

  param "policy_document" {
    type        = string
    description = "The policy document."
    default     = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowAllActionsAllResources",
          "Effect": "Allow",
          "Action": "*",  # Grants all actions
          "Resource": "*"  # Grants access to all resources
        }
      ]
    })
  }

  step "pipeline" "create_iam_policy" {
    pipeline   = aws.pipeline.create_iam_policy
    args = {
      conn            = param.conn
      policy_name     = param.policy_name
      policy_document = param.policy_document
    }
  }

  step "container" "create_iam_user" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-user",
      "--user-name", param.user_name,
    ]

    env = connection.aws[param.conn].env
  }

  step "sleep" "sleep_60_seconds" {
    depends_on = [ step.pipeline.create_iam_policy ]
    duration   = "60s"
  }

  step "query" "get_iam_policy_arn" {
    depends_on = [step.sleep.sleep_60_seconds]
    database   = var.database
    sql        = <<-EOQ
      select
        arn
      from
        aws_iam_policy
      where
        name = '${param.policy_name}'
    EOQ
  }

  step "container" "attach_user_policy" {
    image      = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.query.get_iam_policy_arn]
    cmd = [
      "iam", "attach-user-policy",
      "--user-name", param.user_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn
    ]

    env = connection.aws[param.conn].env
  }

  step "query" "get_user_with_iam_star_star_policy_attached" {
    depends_on = [step.container.attach_user_policy]
    database   = var.database
    sql        = <<-EOQ
      with star_star_policy as (
        select
          arn,
          count(*) as num_bad_statements
        from
          aws_iam_policy,
          jsonb_array_elements(policy_std -> 'Statement') as s,
          jsonb_array_elements_text(s -> 'Resource') as resource,
          jsonb_array_elements_text(s -> 'Action') as action
        where
          s ->> 'Effect' = 'Allow'
          and resource = '*'
          and (
            (action = '*'
            or action = '*:*'
            )
          )
          and is_attached
          and not is_aws_managed
          and arn = '${step.query.get_iam_policy_arn.rows[0].arn}'
        group by
          arn,
          is_aws_managed
      )
      select distinct
        concat(name, '-', attached_arns.policy_arn, ' [', account_id, ']') as title,
        attached_arns.policy_arn,
        name as user_name,
        account_id,
        sp_connection_name as conn
      from
        aws_iam_user,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        name = '${param.user_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on      = [step.query.get_user_with_iam_star_star_policy_attached]
    for_each        = { for item in step.query.get_user_with_iam_star_star_policy_attached.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_with_policy_star_star_attached
    args = {
      title                  = each.value.title
      user_name              = each.value.user_name
      policy_arn             = each.value.policy_arn
      account_id             = each.value.account_id
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "detach_user_star_star_policy"
      enabled_actions        = ["detach_user_star_star_policy"]
    }
  }

  step "sleep" "sleep_70_seconds" {
    depends_on = [ step.pipeline.run_detection ]
    duration   = "70s"
  }

  step "query" "get_details_after_detection" {
    depends_on = [step.sleep.sleep_70_seconds]
    database   = var.database
    sql = <<-EOQ
      with star_star_policy as (
        select
          arn,
          count(*) as num_bad_statements
        from
          aws_iam_policy,
          jsonb_array_elements(policy_std -> 'Statement') as s,
          jsonb_array_elements_text(s -> 'Resource') as resource,
          jsonb_array_elements_text(s -> 'Action') as action
        where
          s ->> 'Effect' = 'Allow'
          and resource = '*'
          and (
            (action = '*'
            or action = '*:*'
            )
          )
          and is_attached
          and not is_aws_managed
          and arn = '${step.query.get_iam_policy_arn.rows[0].arn}'
        group by
          arn,
          is_aws_managed
      )
      select distinct
        concat(name, '-', attached_arns.policy_arn, ' [', account_id, ']') as title,
        attached_arns.policy_arn,
        name as user_name,
        account_id,
        sp_connection_name as conn
      from
        aws_iam_user,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
         name = '${param.user_name}';
    EOQ
  }

  step "container" "delete_iam_user" {
    depends_on = [step.query.get_details_after_detection]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "delete-user",
      "--user-name", param.user_name
    ]

    env = connection.aws[param.conn].env
  }

  step "pipeline" "delete_iam_policy" {
    depends_on = [step.container.delete_iam_user]
    pipeline   = aws.pipeline.delete_iam_policy
    args = {
      conn        = param.conn
      policy_arn  = step.query.get_iam_policy_arn.rows[0].arn
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_user"                              = !is_error(step.container.create_iam_user) ? "pass" : "fail: ${error_message(step.container.create_iam_user)}"
      "create_iam_policy"                             = !is_error(step.pipeline.create_iam_policy) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_policy)}"
      "get_iam_policy_arn"                            = length(step.query.get_iam_policy_arn.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "attach_user_policy"                           = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_user_policy)}"
      "get_user_with_iam_star_star_policy_attached" = length(step.query.get_user_with_iam_star_star_policy_attached.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "get_details_after_detection"                   = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
      "delete_iam_user"                              = !is_error(step.container.delete_iam_user) ? "pass" : "fail: ${error_message(step.container.delete_iam_user)}"
      "delete_iam_policy"                             = !is_error(step.pipeline.delete_iam_policy) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_policy)}"
    }
  }
}
