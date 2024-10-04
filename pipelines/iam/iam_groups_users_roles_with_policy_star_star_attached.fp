locals {
  iam_groups_users_roles_with_policy_star_star_attached_query = <<-EOQ
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
      join star_star_policy s on s.arn = attached_arns.policy_arn;
  EOQ
}

variable "iam_groups_users_roles_with_policy_star_star_attached_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_groups_users_roles_with_policy_star_star_attached_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_groups_users_roles_with_policy_star_star_attached_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_groups_users_roles_with_policy_star_star_attached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "detach_star_star_policy"]
}

trigger "query" "detect_and_correct_iam_groups_users_roles_with_policy_star_star_attached" {
  title         = "Detect & correct IAM entities attached with policy star star"
  description   = "Detects IAM entities (users, roles, groups) attached with the policy star star and then detaches the policy."

  enabled  = var.iam_groups_users_roles_with_policy_star_star_attached_trigger_enabled
  schedule = var.iam_groups_users_roles_with_policy_star_star_attached_trigger_schedule
  database = var.database
  sql      = local.iam_groups_users_roles_with_policy_star_star_attached_query

  capture "insert" {
    pipeline = pipeline.correct_iam_groups_users_roles_with_policy_star_star_attached
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_groups_users_roles_with_policy_star_star_attached
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_groups_users_roles_with_policy_star_star_attached" {
  title         = "Detect & correct IAM entities attached with policy star star"
  description   = "Detects IAM entities (users, roles, groups) attached with the policy star star and then detaches the policy."

  param "database" {
    type        = string
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_groups_users_roles_with_policy_star_star_attached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_groups_users_roles_with_policy_star_star_attached
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_iam_groups_users_roles_with_policy_star_star_attached" {
  title         = "Correct IAM entities attached with policy star star"
  description   = "Runs corrective action to detach the star starpolicy from IAM entities (users, roles, groups)."

  param "items" {
    type = list(object({
      title          = string
      entity_name    = string
      entity_type    = string
      policy_arn     = string
      account_id     = string
      cred           = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM entities attached with star star policy."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_group_user_role_with_policy_star_star_attached
    args = {
      title              = each.value.title
      entity_name        = each.value.entity_name
      entity_type        = each.value.entity_type
      policy_arn         = each.value.policy_arn
      account_id         = each.value.account_id
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_iam_group_user_role_with_policy_star_star_attached" {
  title         = "Correct IAM entity attached with policy star star"
  description   = "Runs corrective action to detach the star star policy from IAM entity."

  param "title" {
    type        = string
    description = local.description_title
  }

  param "entity_name" {
    type        = string
    description = "The name of the IAM entity (user, role, or group)."
  }

  param "entity_type" {
    type        = string
    description = "The type of IAM entity (user, role, or group)."
  }

  param "policy_arn" {
    type        = string
    description = "The ARN of the policy to be detached."
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "notifier" {
    type        = string
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(string)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_groups_users_roles_with_policy_star_star_attached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM ${param.entity_type} ${param.entity_name} attached with star star policy ${param.policy_arn}."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped IAM ${param.entity_type} ${param.entity_name}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_star_star_policy" = {
          label        = "Detach star star policy from IAM entity (user, group, role)"
          value        = "detach_star_star_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.detach_iam_policy
          pipeline_args = {
            entity_name  = param.entity_name
            entity_type  = param.entity_type
            policy_arn   = param.policy_arn
            cred         = param.cred
          }
          success_msg = "Detached star star policy ${param.policy_arn} from IAM ${param.entity_type} ${param.entity_name}."
          error_msg   = "Error detaching star star policy ${param.policy_arn} from IAM ${param.entity_type} ${param.entity_name}."
        }
      }
    }
  }
}

pipeline "detach_iam_policy" {
  title       = "Detach IAM Policy"
  description = "Detaches the specified managed policy from the specified IAM user, role, or group."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "entity_name" {
    type        = string
    description = "The name of the IAM entity (user, role, or group) from which the policy will be detached."
  }

  param "entity_type" {
    type        = string
    description = "The type of IAM entity (user, role, or group)."
  }

  param "policy_arn" {
    type        = string
    description = "The Amazon Resource Name (ARN) of the IAM policy to detach."
  }

  step "container" "detach_user_policy" {
		if = param.entity_type == "user"
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "detach-user-policy",
      "--user-name", param.entity_name,
      "--policy-arn", param.policy_arn,
    ]

    env = credential.aws[param.cred].env
  }

  step "container" "detach_role_policy" {
		if = param.entity_type == "role"
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "detach-role-policy",
      "--role-name", param.entity_name,
      "--policy-arn", param.policy_arn,
    ]

    env = credential.aws[param.cred].env
  }

	step "container" "detach_group_policy" {
		if = param.entity_type == "group"
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "detach-group-policy",
      "--group-name", param.entity_name,
      "--policy-arn", param.policy_arn,
    ]

    env = credential.aws[param.cred].env
  }
}
