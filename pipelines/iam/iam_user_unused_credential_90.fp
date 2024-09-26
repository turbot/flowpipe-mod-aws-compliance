locals {
  iam_user_unused_credentials_90_query = <<-EOQ
	  select
			concat(u.name, ' [', u.account_id, ']') as title,
			access_key_id,
			u.name as user_name,
			u._ctx ->> 'connection_name' as cred,
			case
				when
					r.password_enabled and r.password_last_used is null and r.password_last_changed < (current_date - interval '90' day)
					OR r.password_enabled and r.password_last_used  < (current_date - interval '90' day) then true else false
				end as password_disable
			from
				aws_iam_user as u
				join aws_iam_access_key as k on u.name = k.user_name
				join aws_iam_credential_report as r on r.user_name = u.name
			where
				access_key_last_used_date < (current_date - interval '90' day);
  EOQ
}

trigger "query" "detect_and_deactivate_iam_user_unused_credentials_90" {
  title         = "Detect & correct IAM User Unused Access Keys 90 Days"
  description   = "Detects IAM user credentials that have been unused for 90 days and deactivates them."
  tags          = merge(local.iam_common_tags, { class = "security" })

  enabled  = var.iam_user_unused_credentials_90_trigger_enabled
  schedule = var.iam_user_unused_credentials_90_trigger_schedule
  database = var.database
  sql      = local.iam_user_unused_credentials_90_query

  capture "insert" {
    pipeline = pipeline.deactivate_iam_user_unused_credentials_90
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_deactivate_iam_user_unused_credentials_90" {
  title         = "Detect & correct IAM User Unused Access Keys 90 Days"
  description   = "Detects IAM user credentials that have been unused for 90 days and deactivates them."
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
    default     = var.iam_user_unused_credentials_90_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_unused_credentials_90_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.iam_user_unused_credentials_90_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.deactivate_iam_user_unused_credentials_90
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

pipeline "deactivate_iam_user_unused_credentials_90" {
  title         = "Deactivate IAM User Unused Access Keys 90 Days"
  description   = "Runs corrective action to deactivate IAM user credentials that have been unused for 90 days."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title         = string
      user_name     = string
      account_id    = string
      access_key_id = string
			password_disable = bool
      cred          = string
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
    default     = var.iam_user_unused_credentials_90_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_unused_credentials_90_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} IAM user credentials that have been unused for 90 days."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.access_key_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_user_unused_credential_90
    args = {
      title              = each.value.title
      user_name          = each.value.user_name
      access_key_id      = each.value.access_key_id
			password_disable   = each.value.password_disable
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}


pipeline "correct_one_iam_user_unused_credential_90" {
  title         = "Correct One IAM User Unused Credential"
  description   = "Runs corrective action to deactivate one IAM user credential that has been unused for 90 days."
  tags          = merge(local.iam_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "user_name" {
    type        = string
    description = "The name of the IAM user."
  }

  param "password_disable" {
    type        = bool
    description = "The name of the IAM user."
  }

  param "access_key_id" {
    type        = string
    description = "The access key ID of the IAM user."
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
    default     = var.iam_user_unused_credentials_90_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.iam_user_unused_credentials_90_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected IAM user credential for ${param.title} that has been unused for 90 days."
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
            text     = "Skipped IAM user access keys for ${param.title} that has been unused for 90 days."
          }
          success_msg = ""
          error_msg   = ""
        },
        "deactivate_access_key" = {
          label        = "Deactivate Access Key"
          value        = "deactivate_access_key"
          style        = local.style_alert
          pipeline_ref = pipeline.deactivate_access_key_and_disable_console_access
          pipeline_args = {
            user_name     = param.user_name
						password_disable = param.password_disable
            access_key_id = param.access_key_id
            cred          = param.cred
          }
          success_msg = "Deactivated IAM user access keys ${param.title}."
          error_msg   = "Error deactivating IAM user access keys ${param.title}."
        }
      }
    }
  }
}


variable "iam_user_unused_credentials_90_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "iam_user_unused_credentials_90_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "iam_user_unused_credentials_90_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "iam_user_unused_credentials_90_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "deactivate_access_key"]
}


// pipeline "deactivate_access_key_and_disable_console_access" {
//   title       = "Deactivate Access Key and Disable Console Access"
//   description = "Deactivates the IAM user's access key and disables console access by deleting the login profile."

//   param "cred" {
//     type        = string
//     description = "The credentials to use for AWS CLI commands."
//     default     = "default"
//   }

//   param "user_name" {
//     type        = string
//     description = "The name of the IAM user."
//   }

//   param "password_disable" {
//     type        = bool
//     description = "The name of the IAM user."
//   }

//   param "access_key_id" {
//     type        = string
//     description = "The access key ID of the IAM user."
//   }

//   step "container" "deactivate_access_key" {
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "update-access-key",
//       "--access-key-id", param.access_key_id,
//       "--status", "Inactive",
//       "--user-name", param.user_name
//     ]

//     env = credential.aws[param.cred].env
//   }

//   step "container" "delete_login_profile" {
//     if = param.password_disable
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "delete-login-profile",
//       "--user-name", param.user_name
//     ]

//     env = credential.aws[param.cred].env
//   }

// }

