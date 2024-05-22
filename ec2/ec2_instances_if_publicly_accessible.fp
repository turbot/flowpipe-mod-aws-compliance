locals {
  ec2_instances_if_publicly_accessible_query = <<-EOQ
    select
      concat(instance_id, ' [', region, '/', account_id, ']') as title,
      instance_id,
      region,
      _ctx ->> 'connection_name' as cred,
      public_ip_address
    from
      aws_ec2_instance
    where
      public_ip_address is not null;
  EOQ
}

trigger "query" "detect_and_correct_ec2_instances_if_publicly_accessible" {
  title         = "Detect & correct EC2 instances if publicly accessible"
  description   = "Detects EC2 instances with public IP addresses and executes the chosen action."
  documentation = file("./ec2/docs/detect_and_correct_ec2_instances_if_publicly_accessible_trigger.md")
  tags          = merge(local.ec2_common_tags, { class = "security" })

  enabled  = var.ec2_instances_if_publicly_accessible_trigger_enabled
  schedule = var.ec2_instances_if_publicly_accessible_trigger_schedule
  database = var.database
  sql      = local.ec2_instances_if_publicly_accessible_query

  capture "insert" {
    pipeline = pipeline.correct_ec2_instances_if_publicly_accessible
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ec2_instances_if_publicly_accessible" {
  title         = "Detect & correct EC2 instances if publicly accessible"
  description   = "Detects EC2 instances with public IP addresses and performs the chosen action."
  documentation = file("./ec2/docs/detect_and_correct_ec2_instances_if_publicly_accessible.md")
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
    default     = var.ec2_instances_if_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_if_publicly_accessible_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ec2_instances_if_publicly_accessible_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ec2_instances_if_publicly_accessible
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

pipeline "correct_ec2_instances_if_publicly_accessible" {
  title         = "Correct EC2 instances if publicly accessible"
  description   = "Executes corrective actions on EC2 instances with public IP addresses."
  documentation = file("./ec2/docs/correct_ec2_instances_if_publicly_accessible.md")
  tags          = merge(local.ec2_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title             = string,
      instance_id       = string,
      region            = string,
      cred              = string,
      public_ip_address = string
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
    default     = var.ec2_instances_if_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_if_publicly_accessible_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EC2 instances that are publicly accessible."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.instance_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ec2_instance_if_publicly_accessible
    args = {
      title              = each.value.title,
      instance_id        = each.value.instance_id,
      region             = each.value.region,
      cred               = each.value.cred,
      public_ip_address  = each.value.public_ip_address,
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_ec2_instance_if_publicly_accessible" {
  title         = "Correct one EC2 instance if publicly accessible"
  description   = "Runs corrective action on an EC2 instance with a public IP address."
  documentation = file("./ec2/docs/correct_one_ec2_instance_if_publicly_accessible.md")
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

  param "public_ip_address" {
    type        = string
    description = "Public IP address of the EC2 instance."
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
    default     = var.ec2_instances_if_publicly_accessible_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_if_publicly_accessible_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      detect_msg         = "Detected publicly accessible EC2 instance ${param.title}.",
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions,
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped publicly accesible EC2 instance ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        // TODO: Figure out other actions like Removing Public IP during Instance Launch
        // "remove_public_ip" = {
        //   label        = "Remove Public IP"
        //   value        = "remove_public_ip"
        //   style        = local.style_alert
        //   pipeline_ref = local.aws_pipeline_modify_ec2_instance
        //   pipeline_args = {
        //     instance_id = param.instance_id,
        //     action      = "terminate_instance",
        //     region      = param.region,
        //     cred        = param.cred
        //   }
        //   success_msg = "Public IP removed from EC2 instance ${param.title}."
        //   error_msg   = "Error removing public IP from EC2 instance ${param.title}."
        // }
        "terminate_instance" = {
          label        = "Terminate Instance"
          value        = "terminate_instance"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_terminate_ec2_instances
          pipeline_args = {
            instance_ids = [param.instance_id]
            region       = param.region
            cred         = param.cred
          }
          success_msg = "Deleted EC2 Instance ${param.title}."
          error_msg   = "Error deleting EC2 Instance ${param.title}."
        }
      }
    }
  }
}

variable "ec2_instances_if_publicly_accessible_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ec2_instances_if_publicly_accessible_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "ec2_instances_if_publicly_accessible_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use for the detected item, used if no input is provided."
}

variable "ec2_instances_if_publicly_accessible_enabled_actions" {
  type        = list(string)
  default     = ["skip", "terminate_instance"]
  description = "The list of enabled actions to provide for selection."
}
