locals {
  cloudtrail_trail_logs_encrypted_with_kms_cmk_query = <<-EOQ
    select
      concat(name, ' [', region, '/', account_id, ']') as title,
      region,
      _ctx ->> 'connection_name' as cred,
      name
    from
      aws_cloudtrail_trail
    where
      region = home_region
      and kms_key_id is null
      and account_id = '533793682495' and name = 'tewsr';
  EOQ
}

trigger "query" "detect_and_correct_cloudtrail_trail_logs_encrypted_with_kms_cmk" {
  title       = "Detect & Correct Cloud Trail logs not encrypted with cmk"
  description = "Detects Cloud Trail logs not encrypted with cmk and runs your chosen action."
  // // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_logs_encrypted_with_kms_cmk_trigger.md")
  // tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  enabled  = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_trigger_enabled
  schedule = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trail_logs_encrypted_with_kms_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_logs_encrypted_with_kms_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trail_logs_encrypted_with_kms_cmk" {
  title       = "Detect & Correct Cloud Trail logs not encrypted with cmk"
  description = "Detects Cloud Trail logs not encrypted with cmk and runs your chosen action."
  // // documentation = file("./cloudtrail/docs/detect_and_correct_cloudtrail_trail_logs_encrypted_with_kms_cmk.md")
  // tags          = merge(local.cloudtrail_common_tags, { class = "unused", type = "featured" })

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
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_logs_encrypted_with_kms_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_logs_encrypted_with_kms_cmk
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

pipeline "correct_cloudtrail_trail_logs_encrypted_with_kms_cmk" {
  title       = "Correct Cloud Trail logs not encrypted with cmk"
  description = "Executes corrective actions on Cloud Trail logs not encrypted with cmk."
  // // documentation = file("./cloudtrail/docs/correct_cloudtrail_trail_logs_encrypted_with_kms_cmk.md")
  // tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title  = string
      name   = string
      region = string
      cred   = string
    }))
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
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} Cloud Trail logs not encrypted with cmk."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_logs_encrypted_with_kms_cmk
    args = {
      title              = each.value.title
      name               = each.value.name
      region             = each.value.region
      cred               = each.value.cred
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_logs_encrypted_with_kms_cmk" {
  title       = "Correct one Cloud Trail logs not encrypted with cmk"
  description = "Runs corrective action on a single Cloud Trail logs not encrypted with cmk."
  // // documentation = file("./cloudtrail/docs/correct_one_cloudtrail_classic_load_balancer_without_connection_draining_disabled.md")
  // tags          = merge(local.cloudtrail_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the Cloud Trail trail."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_encrypted_with_kms_cmk_enabled_actions
  }

  param "cloudtrail_cmk_key_id" {
    type        = string
    description = "The id of the cmk to use for encryption."
    default     = var.cloudtrail_cmk_key_id
  }

  param "cloudtrail_policy_name" {
    type        = string
    description = "The name of the policy to use for encryption."
    default     = var.cloudtrail_policy_name
  }

  param "cloudtrail_policy" {
    type        = string
    description = "The policy to use for encryption."
    default = jsonencode({
    "Version": "2012-10-17",
    "Id": "key-default-1",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::533793682495:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
})
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected Cloud Trail logs ${param.title} not encrypted with cmk."
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
            send     = param.notification_level == "verbose"
            text     = "Skipped Cloud Trail logs ${param.title} not encrypted with cmk."
          }
          success_msg = "Skipped Cloud Trail logs ${param.title} not encrypted with cmk."
          error_msg   = "Error skipping Cloud Trail logs ${param.title} not encrypted with cmk."
        },
        "encrypt_cloud_trail_logs" = {
          label        = "Encrypt Cloud Trail logs"
          value        = "encrypt_cloud_trail_logs"
          style        = local.style_alert
          pipeline_ref = pipeline.encrypt_cloud_trail_logs
          pipeline_args = {
            key_id      = param.cloudtrail_cmk_key_id
            region      = param.region
            trail_name  = param.name
            policy_name = param.cloudtrail_policy_name
            policy      = param.cloudtrail_policy
            cred        = param.cred
          }
          success_msg = "Encrypted Cloud Trail logs ${param.title}."
          error_msg   = "Error encrypting Cloud Trail logs ${param.title}."
        }
      }
    }
  }
}

pipeline "encrypt_cloud_trail_logs" {
  title       = "Encrypt Cloud Trail logs"
  description = "Encrypts Cloud Trail logs with a cmk."

  param "key_id" {
    type        = string
    description = "The id of the cmk to use for encryption."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "trail_name" {
    type        = string
    description = "The name of the Cloud Trail trail."
  }

  param "cred" {
    type        = string
    description = local.description_credential
  }

  param "policy_name" {
    type        = string
    description = "The name of the policy to use for encryption."
  }

  param "policy" {
    type        = string
    description = "The policy to use for encryption."
  }

  step "pipeline" "put_kms_key_policy" {
    pipeline = local.aws_pipeline_put_kms_key_policy
    args = {
      key_id      = param.key_id
      policy_name = param.policy_name
      policy      = param.policy
      region      = param.region
      cred        = param.cred
    }
  }

  step "pipeline" "update_cloud_trail" {
    depends_on = [step.pipeline.put_kms_key_policy]
    pipeline   = local.aws_pipeline_update_cloudtrail_trail
    args = {
      trail_name = param.trail_name
      kms_key_id = param.key_id
      region     = param.region
      cred       = param.cred
    }
  }

}

variable "cloudtrail_trail_logs_encrypted_with_kms_cmk_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "cloudtrail_trail_logs_encrypted_with_kms_cmk_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "cloudtrail_trail_logs_encrypted_with_kms_cmk_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "encrypt_cloud_trail_logs"
}

variable "cloudtrail_trail_logs_encrypted_with_kms_cmk_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "encrypt_cloud_trail_logs"]
}

variable "cloudtrail_policy_name" {
  type        = string
  description = "The name of the policy to use for encryption."
  default     = "default"
}

variable "cloudtrail_policy" {
  type        = string
  description = "The policy to use for encryption."
  // default     = "{\"Sid\": \"Allow CloudTrail to encrypt event data store\",\"Effect\": \"Allow\", \"Principal\": {\"Service\": \"cloudtrail.amazonaws.com\"},\"Action\": [\"kms:GenerateDataKey\",\"kms:Decrypt\"],\"Resource\": \"*\"}"
  default = ""
}

variable "cloudtrail_cmk_key_id" {
  type        = string
  description = "The id of the cmk to use for encryption."
  default     = "7f097e1f-6991-40be-bd09-cc7493341231"
}