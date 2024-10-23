locals {
  cloudtrail_trail_logs_not_encrypted_with_kms_cmk_query = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      region,
      sp_connection_name as conn,
      account_id,
      name
    from
      aws_cloudtrail_trail
    where
      region = home_region
      and kms_key_id is null;
  EOQ

  cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action_enum  = ["notify", "skip", "encrypt_cloud_trail_logs"]
  cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions_enum = ["skip", "encrypt_cloud_trail_logs"]
}

variable "cloudtrail_trail_logs_not_encrypted_with_kms_cmk_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_logs_not_encrypted_with_kms_cmk_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "encrypt_cloud_trail_logs"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "encrypt_cloud_trail_logs"]
  enum        = ["skip", "encrypt_cloud_trail_logs"]

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

variable "cloudtrail_trail_logs_not_encrypted_with_kms_cmk_kms_key_id" {
  type        = string
  description = "Specifies the KMS key ID to use to encrypt the logs delivered by CloudTrail."
  default     = "" // Add your key ID here.

  tags = {
    folder = "Advanced/CloudTrail"
  }
}

trigger "query" "detect_and_correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk" {
  title       = "Detect & correct CloudTrail Trail logs not encrypted with KMS CMK"
  description = "Detect CloudTrail trail logs not encrypted with KMS CMK and then skip or encrypt with KMS CMK."

  tags = local.cloudtrail_common_tags

  enabled  = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_trigger_enabled
  schedule = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_trigger_schedule
  database = var.database
  sql      = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_query

  capture "insert" {
    pipeline = pipeline.correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk" {
  title       = "Detect & correct CloudTrail Trail logs not encrypted with KMS CMK"
  description = "Detect CloudTrail trail logs not encrypted with KMS CMK and then skip or encrypt with KMS CMK."

  tags = local.cloudtrail_common_tags

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "kms_key_id" {
    type        = string
    description = "Specifies the KMS key ID to use to encrypt the logs delivered by CloudTrail."
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_kms_key_id
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
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions_enum
  }

  step "query" "detect" {
    database = param.database
    sql      = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk
    args = {
      items              = step.query.detect.rows
      kms_key_id         = param.kms_key_id
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk" {
  title       = "Correct CloudTrail Trail logs not encrypted with KMS CMK"
  description = "Executes corrective actions on CloudTrail trail logs not encrypted with KMS CMK."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title      = string
      account_id = string
      name       = string
      region     = string
      conn       = string
    }))
  }

  param "kms_key_id" {
    type        = string
    description = "Specifies the KMS key ID to use to encrypt the logs delivered by CloudTrail."
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_kms_key_id
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
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} CloudTrail trail log(s) not encrypted with KMS CMK."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_cloudtrail_trail_log_not_encrypted_with_kms_cmk
    args = {
      title              = each.value.title
      name               = each.value.name
      region             = each.value.region
      account_id         = each.value.account_id
      conn               = connection.aws[each.value.conn]
      kms_key_id         = param.kms_key_id
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_cloudtrail_trail_log_not_encrypted_with_kms_cmk" {
  title       = "Correct one CloudTrail trail log not encrypted with KMS CMK"
  description = "Runs corrective action on a single CloudTrail trail logs not encrypted with KMS CMK."

  tags = merge(local.cloudtrail_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the CloudTrail trail."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "account_id" {
    type        = string
    description = "The account ID."
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
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions
    enum        = local.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_enabled_actions_enum
  }

  param "kms_key_id" {
    type        = string
    description = "Specifies the KMS key ID to use to encrypt the logs delivered by CloudTrail."
    default     = var.cloudtrail_trail_logs_not_encrypted_with_kms_cmk_kms_key_id
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected CloudTrail trail log ${param.title} not encrypted with KMS CMK."
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
            send     = param.notification_level == local.level_info
            text     = "Skipped CloudTrail logs ${param.title} not encrypted with KMS CMK."
          }
          success_msg = ""
          error_msg   = ""
        },
        "encrypt_cloud_trail_logs" = {
          label        = "Encrypt CloudTrail logs"
          value        = "encrypt_cloud_trail_logs"
          style        = local.style_alert
          pipeline_ref = pipeline.encrypt_cloud_trail_logs
          pipeline_args = {
            key_id     = param.kms_key_id
            region     = param.region
            trail_name = param.name
            conn       = param.conn
          }
          success_msg = "Encrypted CloudTrail logs ${param.title}."
          error_msg   = "Error encrypting CloudTrail logs ${param.title}."
        }
      }
    }
  }
}

pipeline "encrypt_cloud_trail_logs" {
  title       = "Encrypt CloudTrail logs"
  description = "Encrypts CloudTrail logs with a cmk."
  tags        = merge(local.cloudtrail_common_tags, { folder = "Internal" })

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
    description = "The name of the CloudTrail trail."
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  step "pipeline" "update_cloud_trail" {
    pipeline = aws.pipeline.update_cloudtrail_trail
    args = {
      trail_name = param.trail_name
      kms_key_id = param.key_id
      region     = param.region
      conn       = param.conn
    }
  }
}
