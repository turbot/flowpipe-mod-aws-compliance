locals {
  vpcs_without_flow_logs_query = <<-EOQ
    with vpcs as (
      select
        vpc_id,
        region,
        account_id,
        _ctx ->> 'connection_name' as cred
      from
        aws_vpc
      order by
        vpc_id
    ),
    vpcs_with_flow_logs as (
      select
        resource_id,
        account_id,
        region
      from
        aws_vpc_flow_log
      order by
        resource_id
    )
    select
      concat(v.vpc_id, ' [', v.region, '/', v.account_id, ']') as title,
      v.vpc_id as vpc_id,
      v.region as region,
      v.cred as cred
    from
      vpcs v
      left join vpcs_with_flow_logs f on v.vpc_id = f.resource_id
    where
      f.resource_id is null;
  EOQ
}

trigger "query" "detect_and_correct_vpcs_without_flow_logs" {
  title         = "Detect & correct VPCs without flow logs"
  description   = "Detects VPCs without flow logs and runs your chosen action."
  // documentation = file("./vpc/docs/detect_and_correct_vpcs_without_flow_logs_trigger.md")
  tags          = merge(local.vpc_common_tags, { class = "unused" })

  enabled  = var.vpcs_without_flow_logs_trigger_enabled
  schedule = var.vpcs_without_flow_logs_trigger_schedule
  database = var.database
  sql      = local.vpcs_without_flow_logs_query

  capture "insert" {
    pipeline = pipeline.correct_vpcs_without_flow_logs
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_vpcs_without_flow_logs" {
  title         = "Detect & correct VPCs without flow logs"
  description   = "Detects VPCs without flow logs and runs your chosen action."
  // documentation = file("./vpc/docs/detect_and_correct_vpcs_without_flow_logs.md")
  tags          = merge(local.vpc_common_tags, { class = "unused", type = "featured" })

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
    default     = var.vpcs_without_flow_logs_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.vpcs_without_flow_logs_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_vpcs_without_flow_logs
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

pipeline "correct_vpcs_without_flow_logs" {
  title         = "Correct VPCs without flow logs"
  description   = "Runs corrective action on a collection of VPCs without flow logs."
  // documentation = file("./vpc/docs/correct_vpcs_without_flow_logs.md")
  tags          = merge(local.vpc_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title       = string
      vpc_id      = string
      region      = string
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
    default     = var.vpcs_without_flow_logs_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} VPCs without flow logs."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.vpc_id => row }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_vpc_without_flowlog
    args = {
      title              = each.value.title
      vpc_id             = each.value.vpc_id
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

pipeline "correct_one_vpc_without_flowlog" {
  title         = "Correct one VPC without flow log"
  description   = "Runs corrective action on a VPC without flow log."
  // documentation = file("./vpc/docs/correct_one_vpc_without_flow_log.md")
  tags          = merge(local.vpc_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "vpc_id" {
    type        = string
    description = "The ID of the VPC."
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
    default     = var.vpcs_without_flow_logs_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.vpcs_without_flow_logs_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected VPC ${param.title} without a flow log."
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
            text     = "Skipped VPC ${param.title} without flow log."
          }
          success_msg = ""
          error_msg   = ""
        },
        "create_flow_log" = {
          label        = "Create Flow Log"
          value        = "create_flow_log"
          style        = local.style_alert
          pipeline_ref = pipeline.create_vpc_flowlog
          pipeline_args = {
            vpc_id      = param.vpc_id
            region      = param.region
            cred        = param.cred
          }
          success_msg = "Created Flow log ${param.title}."
          error_msg   = "Error creating Flow log ${param.title}."
        }
      }
    }
  }
}

variable "vpcs_without_flow_logs_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "vpcs_without_flow_logs_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "vpcs_without_flow_logs_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"
}

variable "vpcs_without_flow_logs_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "create_flow_log"]
}
