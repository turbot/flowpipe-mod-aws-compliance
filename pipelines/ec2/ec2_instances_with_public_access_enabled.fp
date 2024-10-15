locals {
  ec2_instances_with_public_access_enabled_query = <<-EOQ
    select
      concat(instance_id, ' [', account_id, '/', region, ']') as title,
      instance_id,
      region,
      public_ip_address,
      sp_connection_name as conn
    from
      aws_ec2_instance
    where
      public_ip_address is not null;
  EOQ
}

variable "ec2_instances_with_public_access_enabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ec2_instances_with_public_access_enabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "ec2_instances_with_public_access_enabled_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use when there are no approvers."
}

variable "ec2_instances_with_public_access_enabled_enabled_actions" {
  type        = list(string)
  default     = ["skip", "stop_instance", "terminate_instance"]
  description = "The list of enabled actions to provide for selection."
}


trigger "query" "detect_and_correct_ec2_instances_with_public_access_enabled" {
  title         = "Detect & correct EC2 instances with public access enabled"
  description   = "Detect EC2 instances with public IP addresses and then skip or stop the instance or terminate the instance."
  

  enabled  = var.ec2_instances_with_public_access_enabled_trigger_enabled
  schedule = var.ec2_instances_with_public_access_enabled_trigger_schedule
  database = var.database
  sql      = local.ec2_instances_with_public_access_enabled_query

  capture "insert" {
    pipeline = pipeline.correct_ec2_instances_with_public_access_enabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ec2_instances_with_public_access_enabled" {
  title         = "Detect & correct EC2 instances with public access enabled"
  description   = "Detect EC2 instances with public IP addresses and then skip or stop the instance or terminate the instance."
  
  tags          = merge(local.ec2_common_tags, { class = "security", recommended = "true" })

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
    default     = var.ec2_instances_with_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_public_access_enabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ec2_instances_with_public_access_enabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ec2_instances_with_public_access_enabled
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

pipeline "correct_ec2_instances_with_public_access_enabled" {
  title         = "Correct EC2 instances with public access enabled"
  description   = "Executes corrective actions on EC2 instances with public IP addresses."
  
  tags          = merge(local.ec2_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title             = string,
      instance_id       = string,
      region            = string,
      conn              = string,
      public_ip_address = string
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
    default     = var.ec2_instances_with_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_public_access_enabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} publicly accessible EC2 instance(s)."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.instance_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ec2_instance_with_public_access_enabled
    args = {
      title              = each.value.title,
      instance_id        = each.value.instance_id,
      region             = each.value.region,
      conn               = connection.aws[each.value.conn],
      public_ip_address  = each.value.public_ip_address,
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_ec2_instance_with_public_access_enabled" {
  title         = "Correct one EC2 instance with public access enabled"
  description   = "Runs corrective action on an EC2 instance with a public IP address."
  
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

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "public_ip_address" {
    type        = string
    description = "Public IP address of the EC2 instance."
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
    default     = var.ec2_instances_with_public_access_enabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_instances_with_public_access_enabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      detect_msg         = "Detected EC2 instance ${param.title} with public IP address ${param.public_ip_address}.",
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions,
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
        // TODO: Figure out other actions like Removing Public IP during Instance Launch
        // "remove_public_ip" = {
        //   label        = "Remove Public IP"
        //   value        = "remove_public_ip"
        //   style        = local.style_alert
        //   pipeline_ref = aws.pipeline.modify_ec2_instance
        //   pipeline_args = {
        //     instance_id = param.instance_id,
        //     action      = "terminate_instance",
        //     region      = param.region,
        //     conn        = param.conn
        //   }
        //   success_msg = "Public IP removed from EC2 instance ${param.title}."
        //   error_msg   = "Error removing public IP from EC2 instance ${param.title}."
        // }
        "stop_instance" = {
          label        = "Stop instance"
          value        = "stop_instance"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.stop_ec2_instances
          pipeline_args = {
            instance_ids = [param.instance_id]
            region       = param.region
            conn         = param.conn
          }
          success_msg = "Stopped EC2 instance ${param.title}."
          error_msg   = "Error stopping EC2 instance ${param.title}."
        }
        "terminate_instance" = {
          label        = "Terminate instance"
          value        = "terminate_instance"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.terminate_ec2_instances
          pipeline_args = {
            instance_ids = [param.instance_id]
            region       = param.region
            conn         = param.conn
          }
          success_msg = "Terminated EC2 instance ${param.title}."
          error_msg   = "Error terminating EC2 instance ${param.title}."
        }
      }
    }
  }
}

