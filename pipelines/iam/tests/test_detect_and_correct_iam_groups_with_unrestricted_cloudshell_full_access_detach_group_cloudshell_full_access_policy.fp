pipeline "test_detect_and_correct_iam_groups_with_unrestricted_cloudshell_full_access_detach_group_cloudshell_full_access_policy" {
  title       = "Test detect and correct IAM groups attached with unrestricted cloudshell full access policy"
  description = "Test detect_and_correct_iam_groups_with_unrestricted_cloudshell_full_access pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "group_name" {
    type        = string
    description = "The name of the group."
    default     = "flowpipe-group-${uuid()}"
  }

   step "container" "create_iam_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-group",
      "--group-name", param.group_name,
    ]

    env = credential.aws[param.cred].env
  }

  step "container" "attach_group_policy" {
   image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.container.create_iam_group]
    cmd = [
      "iam", "attach-group-policy",
      "--group-name", param.group_name,
      "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
    ]

    env = credential.aws[param.cred].env
  }

  step "query" "get_group_with_unrestricted_cloudshell_full_access" {
    depends_on = [step.container.attach_group_policy]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(name, ' [', account_id,  ']') as title,
        name as group_name,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_group
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.group_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.get_group_with_unrestricted_cloudshell_full_access]
    for_each        = { for item in step.query.get_group_with_unrestricted_cloudshell_full_access.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_group_with_unrestricted_cloudshell_full_access
    args = {
      title                  = each.value.title
      group_name             = each.value.group_name
      account_id             = each.value.account_id
      cred                   = each.value.cred
      approvers              = []
      default_action         = "detach_group_cloudshell_full_access_policy"
      enabled_actions        = ["detach_group_cloudshell_full_access_policy"]
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
        name as group_name,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_group
      where
        attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
        and name = '${param.group_name}';
    EOQ
  }

 	step "container" "delete_iam_group" {
    depends_on = [step.query.get_details_after_detection]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "delete-group",
      "--group-name", param.group_name
    ]

    env = credential.aws[param.cred].env
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_group"                                   = !is_error(step.container.create_iam_group) ? "pass" : "fail: ${error_message(step.container.create_iam_group)}"
      "attach_group_policy"                                = !is_error(step.container.attach_group_policy) ? "pass" : "fail: ${error_message(step.container.attach_group_policy)}"
      "get_group_with_unrestricted_cloudshell_full_access" = length(step.query.get_group_with_unrestricted_cloudshell_full_access.rows) == 1 ? "pass" : "fail: Row length is not 3"
      "get_details_after_detection"                       = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
      "delete_iam_group"                                   = !is_error(step.container.delete_iam_group) ? "pass" : "fail: ${error_message(step.container.delete_iam_group)}"
    }
  }
}
