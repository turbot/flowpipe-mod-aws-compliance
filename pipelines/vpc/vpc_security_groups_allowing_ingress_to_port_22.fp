locals {
  vpc_security_groups_allowing_ingress_to_port_22_query = <<-EOQ
    with ingress_rdp_rules as (
      select
        group_id,
        security_group_rule_id,
        region,
        account_id,
        _ctx ->> 'connection_name' as cred    
      from
        aws_vpc_security_group_rule
      where
        type = 'ingress'
        and cidr_ipv4 = '0.0.0.0/0'
        and (
          (
            ip_protocol = '-1'
            and from_port is null
          )
          or (
            from_port >= 22
            and to_port <= 22
          )
        )
    )
    select
      concat(sg.group_id, ' [', sg.region, '/', sg.account_id, ']') as title,
      sg.group_id as group_id,
      ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
      sg.region as region,
      sg._ctx ->> 'connection_name' as cred
    from
      aws_vpc_security_group as sg
      left join ingress_rdp_rules on ingress_rdp_rules.group_id = sg.group_id
    where
      ingress_rdp_rules.group_id is not null;
  EOQ
}

variable "vpc_security_groups_allowing_ingress_to_port_22_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "vpc_security_groups_allowing_ingress_to_port_22_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "vpc_security_groups_allowing_ingress_to_port_22_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use when there are no approvers."
}

variable "vpc_security_groups_allowing_ingress_to_port_22_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "revoke_security_group_rule"]
}

trigger "query" "detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22" {
  title         = "Detect & correct VPC Security groups allowing ingress to port 22"
  description   = "Detect security groups that allow ingress to port 22 and then skip or revoke the security group rule."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22_trigger.md")
  tags          = merge(local.vpc_common_tags, { class = "security" })

  enabled  = var.vpc_security_groups_allowing_ingress_to_port_22_trigger_enabled
  schedule = var.vpc_security_groups_allowing_ingress_to_port_22_trigger_schedule
  database = var.database
  sql      = local.vpc_security_groups_allowing_ingress_to_port_22_query

  capture "insert" {
    pipeline = pipeline.correct_vpc_security_groups_allowing_ingress_to_port_22
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22" {
  title         = "Detect & correct VPC security groups allowing ingress to port 22"
  description   = "Detect security groups that allow ingress to port 22 and then skip or revoke the security group rule."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22.md")

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
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpc_security_groups_allowing_ingress_to_port_22_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpc_security_groups_allowing_ingress_to_port_22
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

pipeline "correct_vpc_security_groups_allowing_ingress_to_port_22" {
  title         = "Correct VPC security groups allowing ingress to port 22"
  description   = "Revoke security group rules to restrict access to port 22 from 0.0.0.0/0."
  // // documentation = file("./vpc/docs/correct_vpc_security_groups_allowing_ingress_to_port_22.md")

  param "items" {
    type = list(object({
      title                  = string,
      group_id               = string,
      security_group_rule_id = string,
      region                 = string,
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
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} VPC Security group rule(s) allowing ingress to port 22 from 0.0.0.0/0."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.group_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_port_22
    args = {
      title                  = each.value.title,
      group_id               = each.value.group_id,
      security_group_rule_id = each.value.security_group_rule_id
      region                 = each.value.region,
      cred                   = each.value.cred,
      notifier               = param.notifier,
      notification_level     = param.notification_level,
      approvers              = param.approvers,
      default_action         = param.default_action,
      enabled_actions        = param.enabled_actions
    }
  }
}

pipeline "correct_one_vpc_security_group_allowing_ingress_to_port_22" {
  title         = "Correct one VPC Security group allowing ingress to port 22"
  description   = "Revoke a VPC security group rule allowing ingress to port 22 from 0.0.0.0/0."
  // // documentation = file("./vpc/docs/correct_one_vpc_security_group_allowing_ingress_to_port_22.md")
  tags          = merge(local.vpc_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "group_id" {
    type        = string
    description = "The ID of the Security group."
  }

  param "security_group_rule_id" {
    type        = string
    description = "The ID of the Security group rule."
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
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC security group ${param.title} with rule ${param.security_group_rule_id} allowing ingress on port 22 from 0.0.0.0/0."
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
            text     = "Skipped VPC security group ${param.title} with rule ${param.security_group_rule_id}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "revoke_security_group_rule" = {
          label        = "Revoke Security Group Rule"
          value        = "revoke_security_group_rule"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.revoke_vpc_security_group_ingress
          pipeline_args = {
            security_group_id      = param.group_id
            security_group_rule_id = param.security_group_rule_id
            region                 = param.region
            cred                   = param.cred
          }
          success_msg = "Revoked ${param.security_group_rule_id} rule from security group ${param.title}."
          error_msg   = "Error revoking ${param.security_group_rule_id} rule from security group ${param.title}."
        }
      }
    }
  }
}

