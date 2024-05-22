locals {
  ec2_instances_not_using_imdsv2_query = <<-EOQ
    select
      concat(instance_id, ' [', region, '/', account_id, ']') as title,
      instance_id,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_ec2_instance
    where
      metadata_options ->> 'HttpTokens' = 'optional';
  EOQ
}

trigger "query" "detect_and_correct_ec2_instances_not_using_imdsv2" {
  title         = "Detect & correct EC2 instances not using IMDSv2"
  description   = "Detects EC2 instances not using IMDSv2 and executes the chosen action."
  documentation = file("./ec2/docs/detect_and_correct_ec2_instances_not_using_imdsv2_trigger.md")
  tags          = merge(local.ec2_common_tags, { class = "security" })

  enabled  = var.ec2_instances_not_using_imdsv2_trigger_enabled
  schedule = var.ec2_instances_not_using_imdsv2_trigger_schedule
  database = var.database
  sql      = local.ec2_instances_not_using_imdsv2_query

  capture "insert" {
    pipeline = pipeline.correct_ec2_instances_not_using_imdsv2
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ec2_instances_not_using_imdsv2" {
  title         = "Detect & correct EC2 instances not using IMDSv2"
  description   = "Detects EC2 instances not using IMDSv2 and performs the chosen action."
  documentation = file("./ec2/docs/detect_and_correct_ec2_instances_not_using_imdsv2.md")
  tags          = merge(local.ec2_common_tags, { class = "security", type = "featured" })

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
    default     = var.ec2_instances_not_using_imdsv2_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_not_using_imdsv2_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ec2_instances_not_using_imdsv2_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ec2_instances_not_using_imdsv2
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

pipeline "correct_ec2_instances_not_using_imdsv2" {
  title         = "Correct EC2 instances not using IMDSv2"
  description   = "Executes corrective actions on EC2 instances not using IMDSv2."
  documentation = file("./ec2/docs/correct_ec2_instances_not_using_imdsv2.md")
  tags          = merge(local.ec2_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title       = string,
      instance_id = string,
      region      = string,
      cred        = string
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
    default     = var.ec2_instances_not_using_imdsv2_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_not_using_imdsv2_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EC2 instances not using IMDSv2."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.instance_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ec2_instance_using_imdsv2
    args = {
      title              = each.value.title,
      instance_id        = each.value.instance_id,
      region             = each.value.region,
      cred               = each.value.cred,
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_ec2_instance_using_imdsv2" {
  title         = "Correct one EC2 instance using IMDSv2"
  description   = "Runs corrective action on an EC2 instance to enable IMDSv2."
  documentation = file("./ec2/docs/correct_one_ec2_instance_using_imdsv2.md")
  tags          = merge(local.ec2_common_tags, { class = "security" })

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
    default     = var.ec2_instances_not_using_imdsv2_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_not_using_imdsv2_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EC2 instance ${param.title} not using IMDSv2."
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
            text     = "Skipped EC2 instance ${param.title} not using IMDSv2."
          }
          success_msg = ""
          error_msg   = ""
        },
        "update_instance_to_imdsv2" = {
          label        = "Delete Snapshot"
          value        = "update_instance_to_imdsv2"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_ec2_instance_metadata_options
          pipeline_args = {
            instance_id = param.instance_id
            http_tokens = "required",
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Deleted EC2 instance ${param.title}."
          error_msg   = "Error deleting EC2 instance ${param.title}."
        }
      }
    }
  }
}

variable "ec2_instances_not_using_imdsv2_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ec2_instances_not_using_imdsv2_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "ec2_instances_not_using_imdsv2_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use for the detected item, used if no input is provided."
}

variable "ec2_instances_not_using_imdsv2_enabled_actions" {
  type        = list(string)
  default     = ["skip", "update_instance_to_imdsv2"]
  description = "The list of enabled actions to provide for selection."
}
