locals {
  iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_query = <<-EOQ
    select
      concat(name, '/', 'user', ' [', account_id,  ']') as title,
      name as entity_name,
      'user' as entity_type,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_user
    where
      attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'

    union

    select
      concat(name, '/', 'role', ' [', account_id,  ']') as title,
      name as entity_name,
      'role' as entity_type,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_role
    where
      attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'

    union

    select
      concat(name, '/', 'group', ' [', account_id,  ']') as title,
      name as entity_name,
      'group' as entity_type,
      account_id,
      _ctx ->> 'connection_name' as cred
    from
      aws_iam_group
    where
      attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
  EOQ
}

variable "iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "detach_cloudshell_fullaccess_policy"]
}

trigger "query" "detect_and_correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess" {
  title         = "Detect & correct IAM entities with unrestricted CloudShellFullAccess policy"
  description   = "Detects IAM entities (users, roles, groups) with unrestricted CloudShellFullAccess policy attached and then detaches that policy."

  enabled  = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_trigger_enabled
  schedule = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_trigger_schedule
  database = var.database
  sql      = local.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_query

  capture "insert" {
    pipeline = pipeline.correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess
    args = {
      items = self.inserted_rows
    }
  }

  capture "update" {
    pipeline = pipeline.correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess
    args = {
      items = self.updated_rows
    }
  }
}

pipeline "detect_and_correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess" {
  title         = "Detect & correct IAM Entities with unrestricted CloudShellFullAccess policy"
  description   = "Detects IAM entities (users, roles, groups) with unrestricted CloudShellFullAccess policy attached and detaches that policy."
  tags          = merge(local.iam_common_tags, { class = "security", type = "featured" })

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
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess
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

pipeline "correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess" {
  title         = "Correct IAM Entities with unrestricted CloudShellFullAccess policy"
  description   = "Runs corrective action to detach the CloudShellFullAccess policy from IAM entities (users, roles, groups)."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title          = string
      entity_name    = string
      entity_type    = string
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
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM entities with unrestricted CloudShellFullAccess policy attached."
  }

  step "pipeline" "correct_item" {
    for_each        = { for row in param.items : row.title => row }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_iam_user_group_role_with_unrestricted_cloudshell_fullaccess
    args = {
      title              = each.value.title
      entity_name        = each.value.entity_name
      entity_type        = each.value.entity_type
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

pipeline "correct_iam_user_group_role_with_unrestricted_cloudshell_fullaccess" {
  title         = "Correct IAM Entity with unrestricted CloudShellFullAccess policy"
  description   = "Runs corrective action to detach the unrestricted CloudShellFullAccess policy from IAM entity (user, role, or group)."

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
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM ${param.entity_type} ${param.entity_name} atttachec with the policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess`."
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
        "detach_cloudshell_fullaccess_policy" = {
          label        = "Detach cloudshell fullaccess policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess`"
          value        = "detach_cloudshell_fullaccess_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.detach_iam_policy
          pipeline_args = {
            entity_name  = param.entity_name
            entity_type  = param.entity_type
            policy_arn   = "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
            cred         = param.cred
          }
          success_msg = "Detached policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess` from IAM ${param.entity_type} ${param.entity_name}."
          error_msg   = "Error detaching policy `arn:aws:iam::aws:policy/AWSCloudShellFullAccess` from IAM ${param.entity_type} ${param.entity_name}."
        }
      }
    }
  }
}
