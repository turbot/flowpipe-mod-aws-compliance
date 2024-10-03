pipeline "test_detect_and_correct_iam_users_with_iam_policy_attached_detach_iam_policy" {
  title       = "Test detect and correct IAM users with IAM policy"
  description = "Test detect_and_correct_iam_users_with_iam_policy_attached pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "user_name" {
    type        = string
    description = "The name of the user."
    default     = "flowpipe-user-dummy"
  }

  param "policy_name" {
    type        = string
    description = "The name of the policy."
    default     = "flowpipe-policy-dummy"
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
      cred        = param.cred
      user_name   = param.user_name
    }
  }

  step "pipeline" "create_iam_policy" {
      depends_on = [step.pipeline.create_iam_user]
    pipeline   = aws.pipeline.create_iam_policy
    args = {
      cred            = param.cred
      policy_name     = param.policy_name
      policy_document = param.policy_document
    }
  }

  step "query" "get_iam_policy_arn" {
    depends_on = [step.pipeline.create_iam_policy]
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
    image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.query.get_iam_policy_arn]
    cmd = [
      "iam", "attach-user-policy",
      "--user-name", param.user_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn
    ]

    env = credential.aws[param.cred].env
  }

  step "pipeline" "run_detection" {
    depends_on = [step.container.attach_user_policy]
    pipeline = pipeline.detect_and_correct_iam_users_with_iam_policy_attached
    args = {
      approvers       = []
      default_action  = "detach_iam_policy"
      enabled_actions = ["detach_iam_policy"]
    }
  }

  step "sleep" "sleep_30_seconds" {
    depends_on = [ step.pipeline.run_detection ]
    duration   = "30s"
  }

  step "query" "get_user_details_after_detection" {
    depends_on = [step.sleep.sleep_30_seconds]
    database = var.database
    sql = <<-EOQ
      select
        name
      from
        aws_iam_user
      where
        attached_policy_arns is  null
        and name = '${param.user_name}'
    EOQ
  }

  step "pipeline" "delete_iam_user" {
    depends_on = [step.query.get_user_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_user
    args = {
      cred        = param.cred
      user_name   = param.user_name
    }
  }

  step "pipeline" "delete_iam_policy" {
    depends_on = [step.pipeline.delete_iam_user]
    pipeline   = aws.pipeline.delete_iam_policy
    args = {
      cred        = param.cred
      policy_arn  = step.query.get_iam_policy_arn.rows[0].arn
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_user"      = !is_error(step.pipeline.create_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_user)}"
      "create_iam_policy" = !is_error(step.pipeline.create_iam_policy) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_policy)}"
      "get_iam_policy_arn" = length(step.query.get_iam_policy_arn.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "attach_user_policy" = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_user_policy)}"
      "get_user_details_after_detection" = length(step.query.get_user_details_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_iam_user" = !is_error(step.pipeline.delete_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_user)}"
    }
  }
}
