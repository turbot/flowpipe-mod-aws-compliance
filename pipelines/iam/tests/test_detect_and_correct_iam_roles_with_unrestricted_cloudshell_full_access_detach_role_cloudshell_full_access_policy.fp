pipeline "test_detect_and_correct_iam_roles_with_unrestricted_cloudshell_full_access_detach_role_cloudshell_full_access_policy" {
  title       = "Test detect and correct IAM roles attached with unrestricted cloudshell full access policy"
  description = "Test detect_and_correct_iam_roles_with_unrestricted_cloudshell_full_access pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "role_name" {
    type        = string
    description = "The name of the role."
    default     = "flowpipe-role-${uuid()}"
  }

  param "assume_role_policy_document" {
    type        = string
    description = "The assume role policy document."
    default     =   jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudtrail.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
        }
      ]
    })
  }

  step "pipeline" "create_iam_role" {
    pipeline   = aws.pipeline.create_iam_role
    args = {
      cred        = param.cred
      role_name   = param.role_name
      assume_role_policy_document = param.assume_role_policy_document
    }
  }

  step "container" "attach_role_policy" {
   image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.pipeline.create_iam_role]
    cmd = [
      "iam", "attach-role-policy",
      "--role-name", param.role_name,
      "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
    ]

    env = credential.aws[param.cred].env
  }

  step "query" "get_role_with_unrestricted_cloudshell_full_access" {
    depends_on = [step.container.attach_role_policy]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(name, ' [', account_id,  ']') as title,
        name as role_name,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_role
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.role_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.get_role_with_unrestricted_cloudshell_full_access]
    for_each        = { for item in step.query.get_role_with_unrestricted_cloudshell_full_access.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_role_with_unrestricted_cloudshell_full_access
    args = {
      title                  = each.value.title
      role_name              = each.value.role_name
      account_id             = each.value.account_id
      cred                   = each.value.cred
      approvers              = []
      default_action         = "detach_role_cloudshell_full_access_policy"
      enabled_actions        = ["detach_role_cloudshell_full_access_policy"]
    }
  }

  step "sleep" "sleep_70_seconds" {
    depends_on = [ step.pipeline.run_detection ]
    duration   = "70s"
  }

  step "query" "get_details_after_detection" {
    depends_on = [step.sleep.sleep_70_seconds]
    database = var.database
    sql = <<-EOQ
      select
        concat(name, ' [', account_id,  ']') as title,
        name as role_name,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_role
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.role_name}';
    EOQ
  }

  step "pipeline" "delete_iam_role" {
    depends_on = [step.query.get_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_role
    args = {
      cred        = param.cred
      role_name   = param.role_name
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_role"                                   = !is_error(step.pipeline.create_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_role)}"
      "attach_role_policy"                                = !is_error(step.container.attach_role_policy) ? "pass" : "fail: ${error_message(step.container.attach_role_policy)}"
      "get_role_with_unrestricted_cloudshell_full_access" = length(step.query.get_role_with_unrestricted_cloudshell_full_access.rows) == 1 ? "pass" : "fail: Row length is not 3"
      "get_details_after_detection"                       = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
      "delete_iam_role"                                   = !is_error(step.pipeline.delete_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_role)}"
    }
  }
}
