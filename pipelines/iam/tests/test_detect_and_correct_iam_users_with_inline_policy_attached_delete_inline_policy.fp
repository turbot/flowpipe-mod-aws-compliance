pipeline "test_detect_and_correct_iam_users_with_inline_policy_attached_delete_inline_policy" {
  title       = "Test detect and correct IAM users with inline policies"
  description = "Test detect_and_correct_iam_users_with_inline_policy_attached pipeline."

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
    description = "The name of the inline policy."
    default     = "flowpipe-policy-${uuid()}"
  }

  param "policy_document" {
    type        = string
    description = "The policy document."
    default     = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AWSCloudTrailCreateLogStream2014110",
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream"
          ],
          "Resource" : [
            "arn:aws:logs:*"
          ]
        },
        {
          "Sid" : "AWSCloudTrailPutLogEvents20141101",
          "Effect" : "Allow",
          "Action" : [
            "logs:PutLogEvents"
          ],
          "Resource" : [
            "arn:aws:logs:*"
          ]
        }
      ]
    })
  }

  step "pipeline" "create_iam_user" {
    pipeline   = aws.pipeline.create_iam_user
    args = {
      conn        = param.conn
      user_name   = param.user_name
    }
  }

  step "container" "attach_inline_policy" {
    image      = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.pipeline.create_iam_user]
    cmd = [
      "iam", "put-user-policy",
      "--user-name", param.user_name,
      "--policy-name", param.policy_name,
      "--policy-document", param.policy_document
    ]
    env = connection.aws[param.conn].env
  }

  step "query" "get_iam_users_with_inline_policy_attached" {
    depends_on = [step.container.attach_inline_policy]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(i ->> 'PolicyName', ' [', account_id, ']') as title,
        i ->> 'PolicyName' as inline_policy_name,
        name as user_name,
        account_id,
        sp_connection_name as conn
      from
        aws_iam_user,
        jsonb_array_elements(inline_policies) as i
      where
        name = '${param.user_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on      = [step.query.get_iam_users_with_inline_policy_attached]
    for_each        = { for item in step.query.get_iam_users_with_inline_policy_attached.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_users_with_inline_policy_attached
    args = {
      title                  = each.value.title
      user_name              = each.value.user_name
      inline_policy_name     = each.value.inline_policy_name
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "delete_inline_policy"
      enabled_actions        = ["delete_inline_policy"]
    }
  }

  step "query" "get_user_details_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql = <<-EOQ
      select
        name
      from
        aws_iam_user
      where
        inline_policies is null
        and name = '${param.user_name}'
    EOQ
  }

  step "pipeline" "delete_iam_user" {
    depends_on = [step.query.get_user_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_user
    args = {
      conn        = param.conn
      user_name   = param.user_name
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_user"                  = !is_error(step.pipeline.create_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_user)}"
      "attach_inline_policy"             = !is_error(step.container.attach_inline_policy) ? "pass" : "fail: ${error_message(step.container.attach_inline_policy)}"
      "get_user_details_after_detection" = length(step.query.get_user_details_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_iam_user"                  = !is_error(step.pipeline.delete_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_user)}"
    }
  }
}
