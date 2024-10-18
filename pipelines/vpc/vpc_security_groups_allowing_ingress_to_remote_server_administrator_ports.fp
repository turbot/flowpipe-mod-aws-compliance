locals {
  vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_query = <<-EOQ
    with bad_rules as (
      select
        group_id,
        security_group_rule_id,
        region,
        account_id,
        sp_connection_name as conn
      from
        aws_vpc_security_group_rule
      where
        type = 'ingress'
        and (
          cidr_ipv4 = '0.0.0.0/0'
          or cidr_ipv6 = '::/0'
        )
        and (
            ( ip_protocol = '-1'      -- all traffic
            and from_port is null
            )
            or (
              from_port <= 22
              and to_port >= 22
            )
            or (
              from_port <= 3389
              and to_port >= 3389
            )
        )
    )
    select
      concat(sg.group_id, ' [', sg.account_id, '/', sg.region, ']') as title,
      sg.group_id as group_id,
      bad_rules.security_group_rule_id as security_group_rule_id,
      sg.region as region,
      sg.sp_connection_name as conn
    from
      aws_vpc_security_group as sg
      left join bad_rules on bad_rules.group_id = sg.group_id
    where
      bad_rules.group_id is not null;
  EOQ
}

variable "vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use when there are no approvers."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "revoke_security_group_rule"]

  tags = {
    folder = "Advanced/VPC"
  }
}

trigger "query" "detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports" {
  title       = "Detect & correct VPC Security groups allowing ingress to remote server administration ports"
  description = "Detect Security group rules that allow ingress from 0.0.0.0/0 to remote server administration ports and then skip or revoke the security group rules."
  tags        = local.vpc_common_tags

  enabled  = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_trigger_enabled
  schedule = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_trigger_schedule
  database = var.database
  sql      = local.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_query

  capture "insert" {
    pipeline = pipeline.correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports" {
  title       = "Detect & correct VPC Security groups allowing ingress to remote server administration ports"
  description = "Detect Security group rules that allow ingress from 0.0.0.0/0 to remote server administration ports and then skip or revoke the security group rules."
  tags        = merge(local.vpc_common_tags, { recommended = "true" })

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
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports
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

pipeline "correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports" {
  title       = "Correct VPC Security groups allowing ingress to remote server administration ports"
  description = "Revoke Security group rules that allow ingress from 0.0.0.0/0 to remote server administration ports."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                  = string,
      group_id               = string,
      security_group_rule_id = string,
      region                 = string,
      conn                   = string
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
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} VPC Security group rule(s) allowing ingress to remote server administration ports (e.g., SSH on port 22, RDP on port 3389) from either 0.0.0.0/0 (IPv4) or ::/0 (IPv6). This poses a critical security risk as it exposes your instances to potential unauthorized access from any IP address on the internet, over both IPv4 and IPv6."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.group_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_remote_server_administration_ports
    args = {
      title                  = each.value.title,
      group_id               = each.value.group_id,
      security_group_rule_id = each.value.security_group_rule_id
      region                 = each.value.region,
      conn                   = connection.aws[each.value.conn],
      notifier               = param.notifier,
      notification_level     = param.notification_level,
      approvers              = param.approvers,
      default_action         = param.default_action,
      enabled_actions        = param.enabled_actions
    }
  }
}

pipeline "correct_one_vpc_security_group_allowing_ingress_to_remote_server_administration_ports" {
  title       = "Correct one VPC Security group allowing ingress to remote server administration ports"
  description = "Revoke a VPC security group rule that allow ingress from 0.0.0.0/0 to remote server administration ports."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

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
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC security group ${param.group_id} with rule ${param.security_group_rule_id} allowing ingress on sensitive ports (e.g., SSH on port 22, RDP on port 3389) from either 0.0.0.0/0 (IPv4) or ::/0 (IPv6). These configurations are dangerous as they allow unrestricted remote access, increasing the risk of unauthorized access and potential security breaches over both IPv4 and IPv6."
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
            text     = "Skipped VPC security group ${param.title} with defective rules."
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
            conn                   = param.conn
          }
          success_msg = "Deleted rule from security group ${param.title}."
          error_msg   = "Error deleting defective rule from security group ${param.title}."
        }
      }
    }
  }
}

