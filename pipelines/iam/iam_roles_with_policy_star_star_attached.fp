locals {
  iam_roles_with_policy_star_star_attached_query = <<-EOQ
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
      concat(name, '-', attached_arns.policy_arn, ' [', account_id, ']') as title,
      attached_arns.policy_arn,
      name as role_name,
      account_id,
      sp_connection_name as conn
    from
      aws_iam_role,
      lateral jsonb_array_elements_text(attached_policy_arns) as attached_arns(policy_arn)
      join star_star_policy s on s.arn = attached_arns.policy_arn
  EOQ

  iam_roles_with_policy_star_star_attached_default_action_enum  = ["notify", "skip", "detach_role_star_star_policy"]
  iam_roles_with_policy_star_star_attached_enabled_actions_enum = ["skip", "detach_role_star_star_policy"]
}

variable "iam_roles_with_policy_star_star_attached_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_roles_with_policy_star_star_attached_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_roles_with_policy_star_star_attached_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "detach_role_star_star_policy"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_roles_with_policy_star_star_attached_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "detach_role_star_star_policy"]
  enum        = ["skip", "detach_role_star_star_policy"]

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_roles_with_policy_star_star_attached" {
  title       = "Detect & correct IAM roles attached with *:* policy"
  description = "Detects IAM roles attached with the *:* policy and then detaches the policy."
  tags        = local.iam_common_tags

  enabled  = var.iam_roles_with_policy_star_star_attached_trigger_enabled
  schedule = var.iam_roles_with_policy_star_star_attached_trigger_schedule
  database = var.database
  sql      = local.iam_roles_with_policy_star_star_attached_query

  capture "insert" {
    pipeline = pipeline.correct_iam_roles_with_policy_star_star_attached
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_roles_with_policy_star_star_attached" {
  title       = "Detect & correct IAM roles attached with *:* policy"
  description = "Detects IAM roles attached with the *:* policy and then detaches the policy."
  tags        = local.iam_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_roles_with_policy_star_star_attached_default_action
    enum        = local.iam_roles_with_policy_star_star_attached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_roles_with_policy_star_star_attached_enabled_actions
    enum        = local.iam_roles_with_policy_star_star_attached_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_roles_with_policy_star_star_attached_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_roles_with_policy_star_star_attached
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

pipeline "correct_iam_roles_with_policy_star_star_attached" {
  title       = "Correct IAM roles attached with *:* policy"
  description = "Runs corrective action to detach the *:* policy from IAM roles."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title      = string
      role_name  = string
      policy_arn = string
      account_id = string
      conn       = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_roles_with_policy_star_star_attached_default_action
    enum        = local.iam_roles_with_policy_star_star_attached_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_roles_with_policy_star_star_attached_enabled_actions
    enum        = local.iam_roles_with_policy_star_star_attached_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM role(s) attached with *:* policy."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_role_with_policy_star_star_attached
    args = {
      title              = each.value.title
      role_name          = each.value.role_name
      policy_arn         = each.value.policy_arn
      account_id         = each.value.account_id
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_role_with_policy_star_star_attached" {
  title       = "Correct one IAM role attached with *:* policy"
  description = "Runs corrective action to detach the *:* policy from a IAM role."
  tags        = merge(local.iam_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "role_name" {
    type        = string
    description = "The name of the IAM role."
  }

  param "policy_arn" {
    type        = string
    description = "The ARN of the policy to be detached."
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_roles_with_policy_star_star_attached_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_roles_with_policy_star_star_attached_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM role ${param.role_name} [${param.account_id}] attached with *:* policy ${param.policy_arn}."
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
            text     = "Skipped IAM role ${param.role_name} [${param.account_id}]."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_role_star_star_policy" = {
          label        = "Detach *:* policy from IAM role ${param.role_name} [${param.account_id}]"
          value        = "detach_role_star_star_policy"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.detach_iam_role_policy
          pipeline_args = {
            role_name  = param.role_name
            policy_arn = param.policy_arn
            conn       = param.conn
          }
          success_msg = "Detached *:* policy ${param.policy_arn} from IAM role ${param.role_name} [${param.account_id}]."
          error_msg   = "Error detaching *:* policy ${param.policy_arn} from IAM role ${param.role_name} [${param.account_id}]."
        }
      }
    }
  }
}
