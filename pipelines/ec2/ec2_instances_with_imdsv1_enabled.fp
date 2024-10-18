locals {
  ec2_instances_with_imdsv1_enabled_query = <<-EOQ
    select
      concat(instance_id, ' [', account_id, '/', region, ']') as title,
      instance_id,
      region,
      sp_connection_name as conn
    from
      aws_ec2_instance
    where
      metadata_options ->> 'HttpTokens' = 'optional';
  EOQ
}

variable "ec2_instances_with_imdsv1_enabled_trigger_enabled" {
  type        = bool
  description = "If true, the trigger is enabled."
  default     = false
}

variable "ec2_instances_with_imdsv1_enabled_trigger_schedule" {
  type        = string
  description = "If the trigger is enabled, run it on this schedule."
  default     = "15m"
}

variable "ec2_instances_with_imdsv1_enabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "ec2_instances_with_imdsv1_enabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "disable_imdsv1"]
}

trigger "query" "detect_and_correct_ec2_instances_with_imdsv1_enabled" {
  title       = "Detect & correct EC2 instances with IMDSv1 enabled"
  description = "Detect EC2 instances and disable IMDSv1."

  tags = local.ec2_common_tags

  enabled  = var.ec2_instances_with_imdsv1_enabled_trigger_enabled
  schedule = var.ec2_instances_with_imdsv1_enabled_trigger_schedule
  database = var.database
  sql      = local.ec2_instances_with_imdsv1_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_ec2_instances_with_imdsv1_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ec2_instances_with_imdsv1_enabled" {
  title       = "Detect & correct EC2 instances with IMDSv1 enabled"
  description = "Detect EC2 instances and disable IMDSv1."


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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.ec2_instances_with_imdsv1_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_imdsv1_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ec2_instances_with_imdsv1_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ec2_instances_with_imdsv1_enabled
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

pipeline "correct_ec2_instances_with_imdsv1_enabled" {
  title       = "Correct EC2 instances with IMDSv1 enabled"
  description = "Disable IMDSv1 for EC2 instances."

  tags = merge(local.ec2_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title       = string,
      instance_id = string,
      region      = string,
      conn        = string
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

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.ec2_instances_with_imdsv1_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_imdsv1_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} EC2 instance(s) with IMDSv1 enabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.instance_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ec2_instance_with_imdsv1_enabled
    args = {
      title              = each.value.title,
      instance_id        = each.value.instance_id,
      region             = each.value.region,
      conn               = connection.aws[each.value.conn],
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_ec2_instance_with_imdsv1_enabled" {
  title       = "Correct one EC2 instance using IMDSv2"
  description = "Disable IMDSv1 for an EC2 instance."

  tags = merge(local.ec2_common_tags, { folder = "Internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "instance_id" {
    type        = string
    description = "The ID of the EC2 instance."
  }

  param "region" {
    type        = string
    description = local.description_region
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
    default     = var.ec2_instances_with_imdsv1_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_imdsv1_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EC2 instance ${param.title} with IMDSv1 enabled."
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
            text     = "Skipped EC2 instance ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "disable_imdsv1" = {
          label        = "Disable IMDSv1"
          value        = "disable_imdsv1"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.modify_ec2_instance_metadata_options
          pipeline_args = {
            instance_id = param.instance_id
            http_tokens = "required",
            region      = param.region
            conn        = param.conn
          }
          success_msg = "Disabled IMDSv1 for EC2 instance ${param.title}."
          error_msg   = "Error disabling IMDSv1 for EC2 instance ${param.title}."
        }
      }
    }
  }
}
