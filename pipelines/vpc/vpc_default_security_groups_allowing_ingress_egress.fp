// TODO: discuss the naming and descriptions
locals {
  vpc_default_security_groups_allowing_ingress_egress_query = <<-EOQ
    with ingress_and_egress_rules as (
      select
        group_id,
        group_name,
        security_group_rule_id,
        region,
        account_id,
        is_egress,
        _ctx ->> 'connection_name' as cred    
      from
        aws_vpc_security_group_rule
      where
        group_name = 'default'
      )
    select
      concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
      case when ingress_and_egress_rules.is_egress then 'egress' else 'ingress' end as type,
      sg.group_id as group_id,
      ingress_and_egress_rules.security_group_rule_id as security_group_rule_id,
      sg.region as region,
      sg._ctx ->> 'connection_name' as cred
    from
      aws_vpc_security_group as sg
      left join ingress_and_egress_rules on ingress_and_egress_rules.group_id = sg.group_id
    where
      sg.group_name = 'default'
      and ingress_and_egress_rules.group_id is not null;
  EOQ
}

variable "vpc_default_security_groups_allowing_ingress_egress_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "vpc_default_security_groups_allowing_ingress_egress_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "vpc_default_security_groups_allowing_ingress_egress_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use when there are no approvers."
}

variable "vpc_default_security_groups_allowing_ingress_egress_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "revoke_security_group_rule"]
}


trigger "query" "detect_and_correct_vpc_default_security_groups_allowing_ingress_egress" {
  title         = "Detect & correct default VPC Security groups allowing ingress egress"
  description   = "Detect default Security group rules that allow both incoming and outgoing internet traffic and then skip or revoke the security group rule."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_default_security_groups_allowing_ingress_egress_trigger.md")

  enabled  = var.vpc_default_security_groups_allowing_ingress_egress_trigger_enabled
  schedule = var.vpc_default_security_groups_allowing_ingress_egress_trigger_schedule
  database = var.database
  sql      = local.vpc_default_security_groups_allowing_ingress_egress_query

  capture "insert" {
    pipeline = pipeline.correct_vpc_default_security_groups_allowing_ingress_egress
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpc_default_security_groups_allowing_ingress_egress" {
  title         = "Detect & correct default VPC Security groups allowing ingress egress"
  description   = "Detect default Security groups that allow both incoming and outgoing internet traffic and then skip or revoke the security group rule."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_default_security_groups_allowing_ingress_egress.md")

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
    default     = var.vpc_default_security_groups_allowing_ingress_egress_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_default_security_groups_allowing_ingress_egress_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpc_default_security_groups_allowing_ingress_egress_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpc_default_security_groups_allowing_ingress_egress
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

pipeline "correct_vpc_default_security_groups_allowing_ingress_egress" {
  title         = "Correct default VPC Security groups allowing ingress egress"
  description   = "Revoke security group rule from the default security group to restrict incoming and outgoing internet traffic."
  // // documentation = file("./vpc/docs/correct_vpc_default_security_groups_allowing_ingress_egress.md")

  param "items" {
    type = list(object({
      title                  = string,
      group_id               = string,
      security_group_rule_id = string,
      region                 = string,
      type                   = string,
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
    default     = var.vpc_default_security_groups_allowing_ingress_egress_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_default_security_groups_allowing_ingress_egress_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} default VPC Security group(s) allowing both ingress and egress traffic."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_egress
    args = {
      title                  = each.value.title,
      group_id               = each.value.group_id,
      security_group_rule_id = each.value.security_group_rule_id
      type                   = each.value.type
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

pipeline "correct_one_vpc_security_group_allowing_ingress_egress" {
  title         = "Correct one default VPC Security group allowing ingress egress"
  description   = "Revoke the security group rule from the default security group Security group entry to restrict ingress and egress."
  // // documentation = file("./vpc/docs/correct_one_vpc_security_group_allowing_ingress_to_remote_server_administration_ports.md")

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

  param "type" {
    type        = string
    description = "The type of the Security group rule (ingress or egress)."
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
    default     = var.vpc_default_security_groups_allowing_ingress_egress_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_default_security_groups_allowing_ingress_egress_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected default VPC security group ${param.title} with security group rule ${param.security_group_rule_id} allowing ingress egress."
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
            text     = "Skipped default VPC security group ${param.title} with security group rule ${param.security_group_rule_id}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "revoke_security_group_rule" = {
          label        = "Revoke Security Group Rule"
          value        = "revoke_security_group_rule"
          style        = local.style_alert
          pipeline_ref = pipeline.revoke_vpc_security_group_rule
          pipeline_args = {
            security_group_id      = param.group_id
            security_group_rule_id = param.security_group_rule_id
            region                 = param.region
            cred                   = param.cred
            type                   = param.type
          }
          success_msg = "Revoked security group rule ${param.security_group_rule_id} from security group ${param.title}."
          error_msg   = "Error revoking security group rule ${param.security_group_rule_id} from security group ${param.title}."
        }
      }
    }
  }
}

pipeline "revoke_vpc_security_group_rule" {
  title       = "Revoke VPC Security Group Rule"
  description = "Removes the specified inbound (ingress) or outbound (egress) rules from a security group."

  param "region" {
    type        = string
    description = local.description_region
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "security_group_id" {
    type        = string
    description = "The ID of the security group."
  }

  param "security_group_rule_id" {
    type        = string
    description = "The ID of the security group rule."
  }

  param "type" {
    type        = string
    description = "The type of the Security group rule (ingress or egress)."    
  }

  step "pipeline" "revoke_security_group_rule_ingress" {
    if            = param.type == "ingress"
    pipeline      = aws.pipeline.revoke_vpc_security_group_ingress
    args = {
      security_group_id      = param.security_group_id
      security_group_rule_id = param.security_group_rule_id
      region                 = param.region
      cred                   = param.cred
    }
  }

  step "pipeline" "revoke_security_group_rule_egress" {
    if            = param.type == "egress"
    pipeline      = aws.pipeline.revoke_vpc_security_group_egress
    args = {
      security_group_id      = param.security_group_id
      security_group_rule_id = param.security_group_rule_id
      region                 = param.region
      cred                   = param.cred
    }
  }
}

