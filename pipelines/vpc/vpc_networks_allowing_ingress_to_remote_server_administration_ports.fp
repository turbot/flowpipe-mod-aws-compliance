locals {
  vpc_networks_allowing_ingress_to_remote_server_administration_ports_query = <<-EOQ
    with bad_rules as (
      select
        network_acl_id,
        att ->> 'RuleNumber' as bad_rule_number,
        region,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_vpc_network_acl,
        jsonb_array_elements(entries) as att
      where
        att ->> 'Egress' = 'false' -- as per aws egress = false indicates the ingress
        and (
          att ->> 'CidrBlock' = '0.0.0.0/0'
          or att ->> 'Ipv6CidrBlock' =  '::/0'
        )
        and att ->> 'RuleAction' = 'allow'
        and (
          (
            att ->> 'Protocol' = '-1' -- all traffic
            and att ->> 'PortRange' is null
          )
          or (
            (att -> 'PortRange' ->> 'From') :: int <= 22
            and (att -> 'PortRange' ->> 'To') :: int >= 22
            and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
          )
          or (
            (att -> 'PortRange' ->> 'From') :: int <= 3389
            and (att -> 'PortRange' ->> 'To') :: int >= 3389
            and att ->> 'Protocol' in('6', '17')  -- TCP or UDP
        )
      )
    ),
    aws_vpc_network_acls as (
      select
        network_acl_id,
        partition,
        region,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_vpc_network_acl
      order by
        network_acl_id,
        region,
        account_id,
        cred
    )
    select
      concat(acl.network_acl_id, '/', bad_rules.bad_rule_number, ' [', acl.region, '/', acl.account_id, ']') as title,
      acl.network_acl_id as network_acl_id,
      (bad_rules.bad_rule_number)::int as rule_number,
      acl.region as region,
      acl.cred as cred
    from
      aws_vpc_network_acls as acl
      left join bad_rules on bad_rules.network_acl_id = acl.network_acl_id
    where
      bad_rules.network_acl_id is not null;
  EOQ
}

trigger "query" "detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports" {
  title         = "Detect & correct VPC Network ACLs allowing ingress to remote server administration ports"
  description   = "Detects Network ACL rules that allow ingress from 0.0.0.0/0 to remote server administration ports."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports_trigger.md")
  tags          = merge(local.vpc_common_tags, { class = "security" })

  enabled  = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_trigger_enabled
  schedule = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_trigger_schedule
  database = var.database
  sql      = local.vpc_networks_allowing_ingress_to_remote_server_administration_ports_query

  capture "insert" {
    pipeline = pipeline.correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports" {
  title         = "Detect & correct VPC Network ACLs allowing ingress to remote server administration ports"
  description   = "Detects Network ACLs that allow risky ingress rules and suggests corrective actions."
  // // documentation = file("./vpc/docs/detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports.md")
  // tags          = merge(local.vpc_common_tags, { class = "security", type = "audit" })

  // tags = merge(local.cis_v300_5_common_tags, {
  //   cis_item_id = "5.2"
  //   cis_level   = "1"
  //   cis_type    = "automated"
  //   service     = "AWS/VPC"
  // })

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
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpc_networks_allowing_ingress_to_remote_server_administration_ports_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports
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

pipeline "correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports" {
  title         = "Correct VPC Network ACLs allowing ingress to remote server administration ports"
  description   = "Modifies Network ACL entries to restrict access to remote server administration ports."
  // // documentation = file("./vpc/docs/correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports.md")
  tags          = merge(local.vpc_common_tags, { class = "security" })

  param "items" {
    type = list(object({
      title           = string,
      network_acl_id  = string,
      rule_number     = number,
      region          = string,
      cred            = string
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
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} VPC network ACLs allowing ingress to remote network server administration ports."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.title => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_network_allowing_ingress_to_remote_server_administration_ports
    args = {
      title              = each.value.title,
      network_acl_id     = each.value.network_acl_id,
      rule_number        = each.value.rule_number
      region             = each.value.region,
      cred               = each.value.cred,
      notifier           = param.notifier,
      notification_level = param.notification_level,
      approvers          = param.approvers,
      default_action     = param.default_action,
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_vpc_network_allowing_ingress_to_remote_server_administration_ports" {
  title         = "Correct one VPC Network ACL allowing ingress to remote server administration ports"
  description   = "Correct a specific Network ACL entry to restrict improper access."
  // // documentation = file("./vpc/docs/correct_one_vpc_network_allowing_ingress_to_remote_server_administration_ports.md")
  tags          = merge(local.vpc_common_tags, { class = "security" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "network_acl_id" {
    type        = string
    description = "The ID of the Network ACL."
  }

  param "rule_number" {
    type        = number
    description = "The rule number associated to the Network ACL."
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
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpc_networks_allowing_ingress_to_remote_server_administration_ports_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC network ACL ${param.network_acl_id} entry with rule number ${param.rule_number} allowing ingress to port 22 or 3389 from 0.0.0.0/0 or ::/0."
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
            text     = "Skipped VPC network ACL ${param.network_acl_id} entry with rule number ${param.rule_number} allowing ingress to port 22 or 3389 from 0.0.0.0/0 or ::/0."
          }
          success_msg = ""
          error_msg   = ""
        },
        "delete_defective_network_acl_entry" = {
          label        = "Delete Network ACL Entry"
          value        = "delete_defective_network_acl_entry"
          style        = local.style_alert
          pipeline_ref = local.aws_pipeline_delete_network_acl_entry
          pipeline_args = {
            network_acl_id = param.network_acl_id
            rule_number    = param.rule_number
            is_egress      = false
            region         = param.region
            cred           = param.cred
          }
          success_msg = "Deleted defective rule ${param.rule_number} from network ACL ${param.network_acl_id} allowing ingress to port 22 or 3389 from 0.0.0.0/0 or ::/0."
          error_msg   = "Error deleting defective rule rule ${param.rule_number} from network ACL ${param.network_acl_id} allowing ingress to port 22 or 3389 from 0.0.0.0/0 or ::/0."
        }
      }
    }
  }
}

variable "vpc_networks_allowing_ingress_to_remote_server_administration_ports_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "vpc_networks_allowing_ingress_to_remote_server_administration_ports_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "vpc_networks_allowing_ingress_to_remote_server_administration_ports_default_action" {
  type        = string
  default     = "notify"
  description = "The default action to use when there are no approvers."
}

variable "vpc_networks_allowing_ingress_to_remote_server_administration_ports_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "delete_defective_network_acl_entry"]
}
