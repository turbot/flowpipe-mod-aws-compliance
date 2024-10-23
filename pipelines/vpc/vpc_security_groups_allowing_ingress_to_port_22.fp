locals {
  vpc_security_groups_allowing_ingress_to_port_22_query = <<-EOQ
    with ingress_rdp_rules as (
      select
        group_id,
        security_group_rule_id,
        ip_protocol,
        from_port,
        to_port,
        coalesce(cidr_ipv4::text, '') as cidr_ipv4,
        coalesce(cidr_ipv6::text, '') as cidr_ipv6,
        region,
        account_id,
        sp_connection_name as conn
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
            from_port <= 22
            and to_port >= 22
          )
        )
    )
    select
      concat(sg.group_id, ' [', sg.region, '/', sg.account_id, ']') as title,
      sg.group_id as group_id,
      ingress_rdp_rules.security_group_rule_id as security_group_rule_id,
      ingress_rdp_rules.ip_protocol as ip_protocol,
      ingress_rdp_rules.from_port as from_port,
      ingress_rdp_rules.to_port as to_port,
      ingress_rdp_rules.cidr_ipv4 as cidr_ipv4,
      ingress_rdp_rules.cidr_ipv6 as cidr_ipv6,
      sg.region as region,
      sg.sp_connection_name as conn
    from
      aws_vpc_security_group as sg
      left join ingress_rdp_rules on ingress_rdp_rules.group_id = sg.group_id
    where
      ingress_rdp_rules.group_id is not null;
  EOQ

  vpc_security_groups_allowing_ingress_to_port_22_default_action_enum  = ["notify", "skip", "revoke_security_group_rule"]
  vpc_security_groups_allowing_ingress_to_port_22_enabled_actions_enum = ["skip", "revoke_security_group_rule"]
}

variable "vpc_security_groups_allowing_ingress_to_port_22_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_port_22_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_port_22_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
  enum        = ["notify", "skip", "revoke_security_group_rule"]

  tags = {
    folder = "Advanced/VPC"
  }
}

variable "vpc_security_groups_allowing_ingress_to_port_22_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "revoke_security_group_rule"]
  enum        = ["skip", "revoke_security_group_rule"]

  tags = {
    folder = "Advanced/VPC"
  }
}

trigger "query" "detect_and_correct_vpc_security_groups_allowing_ingress_to_port_22" {
  title       = "Detect & correct VPC Security groups allowing ingress to port 22"
  description = "Detect security groups that allow ingress to port 22 and then skip or revoke the security group rule."
  tags        = local.vpc_common_tags

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
  title       = "Detect & correct VPC security groups allowing ingress to port 22"
  description = "Detect security groups that allow ingress to port 22 and then skip or revoke the security group rule."
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions_enum
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
  title       = "Correct VPC security groups allowing ingress to port 22"
  description = "Revoke security group rules to restrict access to port 22 from 0.0.0.0/0 or ::/0."
  tags        = merge(local.vpc_common_tags, { folder = "Internal" })

  param "items" {
    type = list(object({
      title                  = string,
      group_id               = string,
      security_group_rule_id = string,
      ip_protocol            = string,
      from_port              = number,
      to_port                = number,
      cidr_ipv4              = string,
      cidr_ipv6              = string,
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions_enum
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} VPC Security group rule(s) allowing ingress to port 22 from 0.0.0.0/0 or ::/0."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.security_group_rule_id => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_security_group_allowing_ingress_to_port_22
    args = {
      title                  = each.value.title,
      group_id               = each.value.group_id,
      security_group_rule_id = each.value.security_group_rule_id,
      ip_protocol            = each.value.ip_protocol,
      to_port                = each.value.to_port,
      from_port              = each.value.from_port,
      cidr_ipv4              = each.value.cidr_ipv4,
      cidr_ipv6              = each.value.cidr_ipv6,
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

pipeline "correct_one_vpc_security_group_allowing_ingress_to_port_22" {
  title       = "Correct one VPC Security group allowing ingress to port 22"
  description = "Revoke a VPC security group rule allowing ingress to port 22 from 0.0.0.0/0 or ::/0."
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

  param "ip_protocol" {
    type        = string
    description = "IP protocol."
  }

  param "from_port" {
    type        = number
    description = "From port."
  }

  param "to_port" {
    type        = number
    description = "To port."
  }

  param "cidr_ipv4" {
    type        = string
    description = "The IPv4 CIDR range."
  }

  param "cidr_ipv6" {
    type        = string
    description = "The IPv6 CIDR range."
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
    enum        = local.notification_level_enum
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_default_action
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_default_action_enum
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions
    enum        = local.vpc_security_groups_allowing_ingress_to_port_22_enabled_actions_enum
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC security group rule ${param.security_group_rule_id} in ${param.title} allowing ingress on protocol ${param.ip_protocol} and ports ${param.from_port}-${param.to_port} from ${coalesce(param.cidr_ipv4, param.cidr_ipv6)}."
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
            text     = "Skipped VPC security group ingress rule ${param.security_group_rule_id} in ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "revoke_security_group_rule" = {
          label        = "Revoke security group rule"
          value        = "revoke_security_group_rule"
          style        = local.style_alert
          pipeline_ref = aws.pipeline.revoke_vpc_security_group_ingress
          pipeline_args = {
            security_group_id      = param.group_id
            security_group_rule_id = param.security_group_rule_id
            region                 = param.region
            conn                   = param.conn
          }
          success_msg = "Revoked VPC security group ingress rule ${param.security_group_rule_id} from ${param.title}."
          error_msg   = "Error revoking VPC security group ingress rule ${param.security_group_rule_id} from security group ${param.title}."
        }
      }
    }
  }
}

