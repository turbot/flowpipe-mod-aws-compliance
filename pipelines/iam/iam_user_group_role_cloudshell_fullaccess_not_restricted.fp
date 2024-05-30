locals {
  iam_entities_with_cloudshell_fullaccess_policy_query = <<-EOQ
    select
      concat(name, ' [', account_id, ']') as title,
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
      concat(name, ' [', account_id, ']') as title,
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
      concat(name, ' [', account_id, ']') as title,
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

trigger "query" "detect_and_detach_iam_entities_with_cloudshell_fullaccess_policy" {
  title         = "Detect & Detach IAM Entities with CloudShellFullAccess Policy"
  description   = "Detects IAM entities (users, roles, groups) with the CloudShellFullAccess policy attached and detaches that policy."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_entities_with_cloudshell_fullaccess_policy_trigger_enabled
  schedule = var.iam_entities_with_cloudshell_fullaccess_policy_trigger_schedule
  database = var.database
  sql      = local.iam_entities_with_cloudshell_fullaccess_policy_query

  capture "insert" {
    pipeline = pipeline.detach_iam_entities_with_cloudshell_fullaccess_policy
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_detach_iam_entities_with_cloudshell_fullaccess_policy" {
  title         = "Detect & Detach IAM Entities with CloudShellFullAccess Policy"
  description   = "Detects IAM entities (users, roles, groups) with the CloudShellFullAccess policy attached and detaches that policy."
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
    default     = var.iam_entities_with_cloudshell_fullaccess_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_entities_with_cloudshell_fullaccess_policy_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_entities_with_cloudshell_fullaccess_policy_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.detach_iam_entities_with_cloudshell_fullaccess_policy
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

pipeline "detach_iam_entities_with_cloudshell_fullaccess_policy" {
  title         = "Detach IAM Entities with CloudShellFullAccess Policy"
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
    default     = var.iam_entities_with_cloudshell_fullaccess_policy_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_entities_with_cloudshell_fullaccess_policy_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM entities with the CloudShellFullAccess policy attached."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.detach_cloudshell_fullaccess_policy_from_one_iam_entity
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

pipeline "detach_cloudshell_fullaccess_policy_from_one_iam_entity" {
  title         = "Detach Policy from One IAM Entity"
  description   = "Runs corrective action to detach the `iam_policy_star_star` policy from one IAM entity (user, role, or group)."
  tags          = merge(local.iam_common_tags, { class = "security" })

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
    default     = var.iam_entities_with_policy_star_star_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_entities_with_policy_star_star_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM entity with the `iam_policy_star_star` policy attached ${param.title}."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped detaching policy from IAM entity ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "detach_policy" = {
          label        = "Detach Policy"
          value        = "detach_policy"
          style        = local.style_alert
          pipeline_ref = pipeline.detach_iam_policy
          pipeline_args = {
            entity_name  = param.entity_name
            entity_type  = param.entity_type
            policy_arn   = "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
            cred         = param.cred
          }
          success_msg = "Detached policy from IAM entity ${param.title}."
          error_msg   = "Error detaching policy from IAM entity ${param.title}."
        }
      }
    }
  }
}


variable "iam_entities_with_cloudshell_fullaccess_policy_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_entities_with_cloudshell_fullaccess_policy_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "iam_entities_with_cloudshell_fullaccess_policy_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "iam_entities_with_cloudshell_fullaccess_policy_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "detach_policy"]
}
