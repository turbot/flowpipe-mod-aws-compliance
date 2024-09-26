locals {
  ec2_classic_load_balancers_with_connection_draining_disabled_query = <<-EOQ
    select
      concat(name, ' [', account_id, '/', region, ']') as title,
      name,
      region,
      _ctx ->> 'connection_name' as cred
    from
      aws_ec2_classic_load_balancer
    where
      not connection_draining_enabled;
  EOQ
}

variable "ec2_classic_load_balancers_with_connection_draining_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "ec2_classic_load_balancers_with_connection_draining_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "ec2_classic_load_balancers_with_connection_draining_disabled_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "ec2_classic_load_balancers_with_connection_draining_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_connection_draining"]
}

trigger "query" "detect_and_correct_ec2_classic_load_balancers_with_connection_draining_disabled" {
  title       = "Detect & correct EC2 classic load balancers with connection draining disabled"
  description = "Detect EC2 classic load balancers with connection draining disabled and then skip or enable connection draining."
  // documentation = file("./ec2/docs/detect_and_correct_ec2_classic_load_balancers_with_connection_draining_disabled_trigger.md")
  tags          = merge(local.ec2_common_tags, { class = "unused" })

  enabled  = var.ec2_classic_load_balancers_with_connection_draining_disabled_trigger_enabled
  schedule = var.ec2_classic_load_balancers_with_connection_draining_disabled_trigger_schedule
  database = var.database
  sql      = local.ec2_classic_load_balancers_with_connection_draining_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_ec2_classic_load_balancers_with_connection_draining_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_ec2_classic_load_balancers_with_connection_draining_disabled" {
  title         = "Detect & correct EC2 classic load balancers with connection draining disabled"
  description   = "Detect EC2 classic load balancers with connection draining disabled and then skip or enable connection draining."
  // documentation = file("./ec2/docs/detect_and_correct_ec2_classic_load_balancers_with_connection_draining_disabled.md")
  tags          = merge(local.ec2_common_tags, { class = "unused", type = "featured" })

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
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.ec2_classic_load_balancers_with_connection_draining_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_ec2_classic_load_balancers_with_connection_draining_disabled
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

pipeline "correct_ec2_classic_load_balancers_with_connection_draining_disabled" {
  title         = "Correct EC2 classic load balancers with connection draining disabled"
  description   = "Executes corrective actions on EC2 classic load balancers with connection draining disabled."
  // documentation = file("./ec2/docs/correct_ec2_classic_load_balancers_with_connection_draining_disabled.md")
  tags          = merge(local.ec2_common_tags, { class = "unused" })

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
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == "verbose"
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} EC2 classic load balancer(s) with connection draining disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_ec2_classic_load_balancer_without_connection_draining_disabled
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

pipeline "correct_one_ec2_classic_load_balancer_without_connection_draining_disabled" {
  title       = "Correct one EC2 classic load balancer with connection draining disabled"
  description = "Runs corrective action on a single EC2 classic load balancer with connection draining disabled."
  // documentation = file("./ec2/docs/correct_one_ec2_classic_load_balancer_without_connection_draining_disabled.md")

  param "title" {
    type        = string
    description = local.description_title
  }

  param "name" {
    type        = string
    description = "The name of the EC2 classic load balancer."
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
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.ec2_classic_load_balancers_with_connection_draining_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected EC2 classic load balancer ${param.title} with connection draining disabled."
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
            text     = "Skipped EC2 classic load balancer ${param.title}."
          }
          success_msg = "Skipped EC2 classic load balancer ${param.title} with connection draining disabled."
          error_msg   = "Error skipping EC2 classic load balancer ${param.title} with connection draining disabled."
        },
        "enable_connection_draining" = {
          label        = "Enable Connection Draining"
          value        = "enable_connection_draining"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_modify_elb_attributes
          pipeline_args = {
            load_balancer_name = param.name
            region             = param.region
            cred               = param.cred
          }
          success_msg = "Enabled connection draining for EC2 classic load balancer ${param.title}."
          error_msg   = "Error enabling connection draining for EC2 classic load balancer ${param.title}."
        }
      }
    }
  }
}


