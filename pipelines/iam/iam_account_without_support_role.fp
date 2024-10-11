locals {
  iam_account_without_support_role_query = <<-EOQ
    with support_role_count as (
      select
        'arn:' || a.partition || ':::' || a.account_id as resource,
        count(policy_arn),
        a.account_id,
        a.sp_connection_name
      from
        aws_account as a
        left join aws_iam_role as r on r.account_id = a.account_id
        left join jsonb_array_elements_text(attached_policy_arns) as policy_arn  on true
      where
        split_part(policy_arn, '/', 2) = 'AWSSupportAccess'
        or policy_arn is null
      group by
        a.account_id,
        a.partition,
        a.sp_connection_name
    )
    select
      account_id as title,
      account_id,
      sp_connection_name as conn
    from
      support_role_count
    where
      count = 0;
  EOQ
}

variable "iam_account_without_support_role_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_without_support_role_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_without_support_role_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "create_support_role"

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_without_support_role_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "create_support_role"]

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_without_support_role_user_arn" {
  type        = string
  description = "Specifies the IAM user arn to be used for creating the support role."
  default     = "" // Add the IAM user name here.

  tags = {
    folder = "Advanced/IAM"
  }
}

variable "iam_account_without_support_role_support_role_name" {
  type        = string
  description = "Specifies the IAM support role that will be created."
  default     = "flowpipe-aws-support-access" // Add the IAM role name here.

  tags = {
    folder = "Advanced/IAM"
  }
}

trigger "query" "detect_and_correct_iam_account_without_support_role" {
  title         = "Detect & correct IAM account without support role"
  description   = "Detects IAM account without support role and then create a new support role."
  tags          = local.iam_common_tags

  enabled  = var.iam_account_without_support_role_trigger_enabled
  schedule = var.iam_account_without_support_role_trigger_schedule
  database = var.database
  sql      = local.iam_account_without_support_role_query

  capture "insert" {
    pipeline = pipeline.correct_iam_account_without_support_role
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_iam_account_without_support_role" {
  title         = "Detect & correct IAM account without support role"
  description   = "Detects IAM account without support role and then create a new support role."
  tags          = local.iam_common_tags

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

  param "user_arn" {
    type        = string
    description = "Specifies the IAM user to be used for creating the support role."
    default     = var.iam_account_without_support_role_user_arn
  }

  param "support_role_name" {
    type        = string
    description = "Specifies the IAM support role that will be created."
    default     = var.iam_account_without_support_role_support_role_name
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_without_support_role_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_without_support_role_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_account_without_support_role_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_account_without_support_role
    args = {
      items              = step.query.detect.rows
      support_role_name  = param.support_role_name
      user_arn           = param.user_arn
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_iam_account_without_support_role" {
   title         = "Correct IAM account without support role"
  description   = "Create a new support role for IAM account without support role"
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title          = string
      account_id     = string
      conn           = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "user_arn" {
    type        = string
    description = "Specifies the IAM user to be used for creating the support role."
    default     = var.iam_account_without_support_role_user_arn
  }

  param "support_role_name" {
    type        = string
    description = "Specifies the IAM support role that will be created."
    default     = var.iam_account_without_support_role_support_role_name
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_without_support_role_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_without_support_role_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} IAM account without support role."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_without_support_role
    args = {
      title              = each.value.title
      account_id         = each.value.account_id
      support_role_name  = param.support_role_name
      user_arn           = param.user_arn
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_iam_account_without_support_role" {
  title         = "Correct one IAM account without support role"
  description   = "Runs corrective action for an IAM account to create a new support role."
  tags          = merge(local.iam_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "account_id" {
    type        = string
    description = "The account ID of the AWS account."
  }

  param "user_arn" {
    type        = string
    description = "Specifies the IAM user arn to be used for creating the support role."
    default     = var.iam_account_without_support_role_user_arn
  }

  param "support_role_name" {
    type        = string
    description = "Specifies the IAM support role that will be created."
    default     = var.iam_account_without_support_role_support_role_name
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
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.iam_account_without_support_role_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_account_without_support_role_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM account ${param.title} without support role."
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
            text     = "Skipped IAM account ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "create_support_role" = {
          label        = "Create support role"
          value        = "create_support_role"
          style        = local.style_alert
          pipeline_ref = pipeline.create_iam_account_support_role
          pipeline_args = {
            user_arn         = param.user_arn
            support_role_name = param.support_role_name
            conn              = param.conn
          }
          success_msg = "Created support role for IAM account ${param.title}."
          error_msg   = "Error creating support role for IAM account ${param.title}."
        }
      }
    }
  }
}

pipeline "create_iam_account_support_role" {
  title       = "Create IAM account support role"
  description = "Creates a new support role for your Amazon Web Services account."

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "support_role_name" {
    type        = string
    description = "Specifies the IAM support role that will be created."
  }

  param "user_arn" {
    type        = string
    description = "Specifies the IAM user to be used for creating the support role."
  }

  step "transform" "generate_assume_role_policy_document" {
    output "policy" {
      value = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Principal" : {
              "AWS" : "${param.user_arn}"
            },
            "Action" : "sts:AssumeRole"
          }
        ]
      })
    }
  }

  step "container" "create_iam_role" {
    depends_on = [step.transform.generate_assume_role_policy_document]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "create-role",
      "--role-name", param.support_role_name,
      "--assume-role-policy-document", step.transform.generate_assume_role_policy_document.output.policy
    ]

    env = connection.aws[param.conn].env
  }

  step "container" "attach_role_policy" {
    depends_on = [step.container.create_iam_role]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "iam", "attach-role-policy",
      "--role-name", param.support_role_name,
      "--policy-arn", "arn:aws:iam::aws:policy/AWSSupportAccess",
    ]

    env = connection.aws[param.conn].env
  }

}
