pipeline "test_detect_and_correct_iam_groups_users_roles_with_policy_star_star_attached_detach_star_star_policy" {
  title       = "Test detect and correct IAM entities attached with star star policy"
  description = "Test detect_and_correct_iam_groups_users_roles_with_policy_star_star_attached pipeline."

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
    default     = "flowpipe-user-${uuid()}"
  }

  param "role_name" {
    type        = string
    description = "The name of the role."
    default     = "flowpipe-role-${uuid()}"
  }

	param "group_name" {
    type        = string
    description = "The name of the group_."
    default     = "flowpipe-group-${uuid()}"
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

  step "pipeline" "create_iam_policy" {
    pipeline   = aws.pipeline.create_iam_policy
    args = {
      cred            = param.cred
      policy_name     = param.policy_name
      policy_document = param.policy_document
    }
  }

  step "pipeline" "create_iam_user" {
    pipeline   = aws.pipeline.create_iam_user
    args = {
      cred        = param.cred
      user_name   = param.user_name
    }
  }

  step "pipeline" "create_iam_role" {
    depends_on = [step.pipeline.create_iam_user]
    pipeline   = aws.pipeline.create_iam_role
    args = {
      cred        = param.cred
      role_name   = param.role_name
      assume_role_policy_document = param.assume_role_policy_document
    }
  }

  step "container" "create_iam_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-group",
      "--group-name", param.group_name,
    ]

    env = credential.aws[param.cred].env
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
    image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.query.get_iam_policy_arn]
    cmd = [
      "iam", "attach-user-policy",
      "--user-name", param.user_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn
    ]

    env = credential.aws[param.cred].env
  }

  step "container" "attach_role_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.container.attach_user_policy]
    cmd = [
      "iam", "attach-role-policy",
      "--role-name", param.role_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn
    ]

    env = credential.aws[param.cred].env
  }

  step "container" "attach_group_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    depends_on = [step.container.attach_role_policy]
    cmd = [
      "iam", "attach-group-policy",
      "--group-name", param.group_name,
      "--policy-arn", step.query.get_iam_policy_arn.rows[0].arn
    ]

    env = credential.aws[param.cred].env
  }

  step "query" "get_entity_with_iam_star_star_policy_attached" {
    depends_on = [step.container.attach_group_policy]
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
        concat(name, '/', 'user', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'user' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_user,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        name = '${param.user_name}'

      union

      select distinct
        concat(name, '/', 'role', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'role' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_role,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        name = '${param.role_name}'

      union

      select distinct
        concat(name, '/', 'group', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'group' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_group,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        and  name = '${param.group_name}';
    EOQ
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.get_entity_with_iam_star_star_policy_attached]
    for_each        = { for item in step.query.get_entity_with_iam_star_star_policy_attached.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_group_user_role_with_policy_star_star_attached
    args = {
      title                  = each.value.title
      entity_name            = each.value.entity_name
      entity_type            = each.value.entity_type
      policy_arn             = each.value.policy_arn
      account_id             = each.value.account_id
      cred                   = each.value.cred
      approvers              = []
      default_action         = "detach_star_star_policy"
      enabled_actions        = ["detach_star_star_policy"]
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
        concat(name, '/', 'user', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'user' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_user,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        name = '${param.user_name}'

      union

      select distinct
        concat(name, '/', 'role', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'role' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_role,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        name = '${param.role_name}'

      union

      select distinct
        concat(name, '/', 'group', ' [', account_id, '/', attached_arns.policy_arn, ']') as title,
        attached_arns.policy_arn,
        name as entity_name,
        'group' as entity_type,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_iam_group,
        lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
        join star_star_policy s on s.arn = attached_arns.policy_arn
      where
        and  name = '${param.group_name}';
    EOQ
  }

  step "pipeline" "delete_iam_user" {
    depends_on = [step.query.get_details_after_detection]
    pipeline   = aws.pipeline.delete_iam_user
    args = {
      cred        = param.cred
      user_name   = param.user_name
    }
  }

  step "pipeline" "delete_iam_role" {
    depends_on = [step.pipeline.delete_iam_user]
    pipeline   = aws.pipeline.delete_iam_role
    args = {
      cred        = param.cred
      role_name   = param.role_name
    }
  }

  step "container" "delete_iam_group" {
    depends_on = [step.pipeline.delete_iam_role]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "delete-group",
      "--group-name", param.group_name
    ]

    env = credential.aws[param.cred].env
  }

  step "pipeline" "delete_iam_policy" {
    depends_on = [step.container.delete_iam_group]
    pipeline   = aws.pipeline.delete_iam_policy
    args = {
      cred        = param.cred
      policy_arn  = step.query.get_iam_policy_arn.rows[0].arn
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_iam_user"                               = !is_error(step.pipeline.create_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_user)}"
      "create_iam_role"                               = !is_error(step.pipeline.create_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_role)}"
      "create_iam_group"                              = !is_error(step.container.create_iam_group) ? "pass" : "fail: ${error_message(step.container.create_iam_group)}"
      "create_iam_policy"                             = !is_error(step.pipeline.create_iam_policy) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_policy)}"
      "get_iam_policy_arn"                            = length(step.query.get_iam_policy_arn.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "attach_user_policy"                            = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_user_policy)}"
      "attach_role_policy"                            = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_role_policy)}"
      "attach_group_policy"                           = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_group_policy)}"
      "get_entity_with_iam_star_star_policy_attached" = length(step.query.get_entity_with_iam_star_star_policy_attached.rows) == 3 ? "pass" : "fail: Row length is not 3"
      "get_details_after_detection"                   = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
      "delete_iam_user"                               = !is_error(step.pipeline.delete_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_user)}"
      "delete_iam_role"                               = !is_error(step.pipeline.delete_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_role)}"
      "delete_iam_group"                              = !is_error(step.container.delete_iam_group) ? "pass" : "fail: ${error_message(step.container.delete_iam_group)}"
      "delete_iam_policy"                             = !is_error(step.pipeline.delete_iam_policy) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_policy)}"
    }
  }
}
