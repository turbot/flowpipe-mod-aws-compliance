locals {
  rds_db_instances_with_encryption_at_rest_disabled_query = <<-EOQ
    select
      concat(r.db_instance_identifier, ' [', r.account_id, '/', r.region, ']') as title,
      r.db_instance_identifier,
      r.region,
      concat(r.db_instance_identifier, '-snapshot-', replace(cast(now() as varchar), ' ', '_')) as snapshot_identifier,
      k.arn as aws_managed_kms_key_arn,
      r.sp_connection_name as conn
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

variable "rds_db_instances_with_encryption_at_rest_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "rds_db_instances_with_encryption_at_rest_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

trigger "query" "detect_and_correct_rds_db_instances_with_encryption_at_rest_disabled" {
  title       = "Detect & correct RDS DB instances with encryption at rest disabled"
  description = "Detect RDS DB instances with encryption at rest disabled."
  tags        = local.rds_common_tags

  enabled  = var.rds_db_instances_with_encryption_at_rest_disabled_trigger_enabled
  schedule = var.rds_db_instances_with_encryption_at_rest_disabled_trigger_schedule
  database = var.database
  sql      = local.rds_db_instances_with_encryption_at_rest_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_rds_db_instances_with_encryption_at_rest_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_rds_db_instances_with_encryption_at_rest_disabled" {
  title       = "Detect & correct RDS DB instances with encryption at rest disabled"
  description = "Detect RDS DB instances with encryption at rest disabled."
  tags        = local.rds_common_tags

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
  }

  step "query" "detect" {
    database = param.database
    sql      = local.rds_db_instances_with_encryption_at_rest_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_rds_db_instances_with_encryption_at_rest_disabled
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
    }
  }
}

pipeline "correct_rds_db_instances_with_encryption_at_rest_disabled" {
  title       = "Correct RDS DB instances with encryption at rest disabled"
  description = "Send notifications for RDS DB instances with encryption at rest disabled."
  tags        = merge(local.rds_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                   = string
      db_instance_identifier  = string
      snapshot_identifier     = string
      aws_managed_kms_key_arn = string
      region                  = string
      conn                    = string
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
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} RDS DB instance(s) with encryption at rest disabled."
  }

  step "message" "notify_items" {
    if       = var.notification_level == local.level_info
    for_each = param.items
    notifier = param.notifier
    text     = "Detected RDS DB instance ${each.value.title} with encryption at rest disabled."
  }
}
