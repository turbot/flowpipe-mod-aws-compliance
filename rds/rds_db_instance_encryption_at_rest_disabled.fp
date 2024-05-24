locals {
  rds_db_instance_without_encryption_query = <<-EOQ
    select
			concat(r.db_instance_identifier, ' [', r.region, '/', r.account_id, ']') as title,
			r.db_instance_identifier,
			r.region,
			concat(r.db_instance_identifier, '-snapshot-', replace(cast(now() as varchar), ' ', '_')) as snapshot_identifier,
			k.arn as aws_managed_kms_key_arn,
			r._ctx ->> 'connection_name' as cred
		from
			aws_rds_db_instance as r
		left join
			aws_kms_key as k on r.region = k.region,
			jsonb_array_elements(k.aliases) as a
		where
			k.key_manager = 'AWS'
			and a ->> 'AliasName' = 'alias/aws/rds'
  		and (not r.storage_encrypted);
  EOQ
}

 trigger "query" "detect_and_correct_rds_db_instance_without_encryption" {
  title         = "Detect & Correct RDS DB Instance without Encryption"
  description   = "Detects RDS DB instances without encryption enabled and runs your chosen action."
  tags          = merge(local.rds_common_tags, { class = "security" })

  enabled  = var.rds_db_instance_without_encryption_trigger_enabled
  schedule = var.rds_db_instance_without_encryption_trigger_schedule
  database = var.database
  sql      = local.rds_db_instance_without_encryption_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instance_without_encryption
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instance_without_encryption" {
  title         = "Detect & Correct RDS DB Instances without Encryption"
  description   = "Detects RDS DB instances without encryption enabled and runs your chosen action."
  tags          = merge(local.rds_common_tags, { class = "security", type = "featured" })

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
    default     = var.rds_db_instance_without_encryption_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_without_encryption_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instance_without_encryption_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instance_without_encryption
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

pipeline "correct_rds_db_instance_without_encryption" {
  title         = "Correct RDS DB Instance without Encryption"
  description   = "Runs corrective action on a collection of RDS DB instances without encryption enabled."
  tags          = merge(local.rds_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title                  = string
      db_instance_identifier = string
			snapshot_identifier    = string
      aws_managed_kms_key_arn = string
      region                 = string
      cred                   = string
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
    default     = var.rds_db_instance_without_encryption_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_without_encryption_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} RDS DB instances without encryption enabled."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.db_instance_identifier => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_without_encryption
    args = {
      title                   = each.value.title
      db_instance_identifier  = each.value.db_instance_identifier
			snapshot_identifier    = each.value.snapshot_identifier
      aws_managed_kms_key_arn = each.value.aws_managed_kms_key_arn
      region                  = each.value.region
      cred                    = each.value.cred
      notifier                = param.notifier
      notification_level      = param.notification_level
      approvers               = param.approvers
      default_action          = param.default_action
      enabled_actions         = param.enabled_actions
    }
  }
}

pipeline "correct_one_rds_db_instance_without_encryption" {
  title         = "Correct one RDS DB Instance without Encryption"
  description   = "Runs corrective action on an RDS DB instance without encryption enabled."
  tags          = merge(local.rds_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "db_instance_identifier" {
    type        = string
    description = "The identifier of the DB instance."
  }

 	param "snapshot_identifier" {
    type        = string
    description = "The snapshot identifier of the DB instance."
  }

  param "aws_managed_kms_key_arn" {
    type        = string
    description = "Enables storage encryption for the DB instance."
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
    default     = var.rds_db_instance_without_encryption_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.rds_db_instance_without_encryption_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected RDS DB instance without encryption enabled ${param.title}."
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
            text     = "Skipped RDS DB instance ${param.title} without encryption enabled."
          }
          success_msg = ""
          error_msg   = ""
        },
        "encrypt_db_instance" = {
          label        = "Encrypt DB Instance"
          value        = "encrypt_db_instance"
          style        = local.style_alert
          pipeline_ref = pipeline.update_rds_encryption
          pipeline_args = {
            db_instance_identifier  = param.db_instance_identifier
						snapshot_identifier     = param.snapshot_identifier
            aws_managed_kms_key_arn = param.aws_managed_kms_key_arn
            region                 = param.region
            cred                   = param.cred
          }
          success_msg = "Encrypted RDS DB instance ${param.title}."
          error_msg   = "Error encrypting RDS DB instance ${param.title}."
        }
      }
    }
  }
}

variable "rds_db_instance_without_encryption_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_instance_without_encryption_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "rds_db_instance_without_encryption_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "encrypt_db_instance"
}

variable "rds_db_instance_without_encryption_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "encrypt_db_instance"]
}


pipeline "update_rds_encryption" {
  title       = "Update RDS Encryption at Rest"
  description = "Enables encryption at rest for an existing RDS instance by creating an encrypted snapshot and restoring it."

  param "cred" {
    type        = string
    description = "AWS Credential"
    default     = "default"
  }

  param "region" {
    type        = string
    description = "AWS Region"
  }

  param "db_instance_identifier" {
    type        = string
    description = "The identifier of the existing RDS instance."
  }

  param "snapshot_identifier" {
    type        = string
    description = "The identifier for the DB snapshot."
  }

  param "encrypted_snapshot_identifier" {
    type        = string
    description = "The identifier for the encrypted DB snapshot."
		default = "snapshot-encrypted-database-1"
  }

  param "new_db_instance_identifier" {
    type        = string
    description = "The identifier for the new DB instance."
		default = "new-encrypted-database-1"
  }

  param "aws_managed_kms_key_arn" {
    type        = string
    description = "The KMS key ID for encryption."
  }

  step "container" "create_db_snapshot" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "rds", "create-db-snapshot",
      "--db-instance-identifier", param.db_instance_identifier,
      "--db-snapshot-identifier", param.snapshot_identifier,
      "--region", param.region
    ]
    env = credential.aws[param.cred].env
  }

step "sleep" "sleep_10_seconds" {
  depends_on = [ step.container.create_db_snapshot ]
  duration   = "300s"
}

  step "container" "copy_db_snapshot" {
    depends_on = [step.sleep.sleep_10_seconds]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "rds", "copy-db-snapshot",
      "--source-db-snapshot-identifier", param.snapshot_identifier,
      "--target-db-snapshot-identifier", param.encrypted_snapshot_identifier,
      "--kms-key-id", param.aws_managed_kms_key_arn,
      "--region", param.region
    ]
    env = credential.aws[param.cred].env
  }

	step "sleep" "sleep_300_seconds" {
		depends_on = [ step.container.copy_db_snapshot ]
		duration   = "300s"
	}

  step "container" "restore_db_instance_from_snapshot" {
    depends_on = [step.sleep.sleep_300_seconds]
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "rds", "restore-db-instance-from-db-snapshot",
      "--db-instance-identifier", param.new_db_instance_identifier,
      "--db-snapshot-identifier", param.encrypted_snapshot_identifier,
      "--region", param.region
    ]
    env = credential.aws[param.cred].env
  }

  step "container" "delete_rds_db_instance" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "rds", "delete-db-instance", "--skip-final-snapshot",
      "--db-instance-identifier", param.db_instance_identifier,
    ]

    env = merge(credential.aws[param.cred].env, { AWS_REGION = param.region })
  }
}
