locals {
  apigateway_rest_api_stage_if_xray_tracing_disabled_query = <<-EOQ
	 select
	 		concat(rest_api_id, ' [', '/', region, '/', account_id, ']') as title,
      rest_api_id,
			name as stage_name,
      region,
			_ctx ->> 'connection_name' as cred
    from
      aws_api_gateway_stage
		where
			not tracing_enabled;
  EOQ
}

trigger "query" "detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled" {
  title         = "Detect & correct API Gateway REST API stage if X-Ray tracing disabled"
  description   = "Detects unattached EIPs (Elastic IP addresses) and runs your chosen action."
  // documentation = file("./apigateway/docs/detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled_trigger.md")
  tags          = merge(local.apigateway_common_tags, { class = "unused" })

  enabled  = var.apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_enabled
  schedule = var.apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_schedule
  database = var.database
  sql      = local.apigateway_rest_api_stage_if_xray_tracing_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_apigateway_rest_api_stage_if_xray_tracing_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled" {
  title         = "Detect & correct VPC EIPs if unattached"
  description   = "Detects unattached EIPs (Elastic IP addresses) and runs your chosen action."
  // documentation = file("./apigateway/docs/detect_and_correct_apigateway_rest_api_stage_if_xray_tracing_disabled.md")
  tags          = merge(local.apigateway_common_tags, { class = "unused", type = "featured" })

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
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.apigateway_rest_api_stage_if_xray_tracing_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_apigateway_rest_api_stage_if_xray_tracing_disabled
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

pipeline "correct_apigateway_rest_api_stage_if_xray_tracing_disabled" {
  title         = "Correct VPC EIPs if unattached"
  description   = "Runs corrective action on a collection of EIPs (Elastic IP addresses) which are unattached."
  // documentation = file("./apigateway/docs/correct_apigateway_rest_api_stage_if_xray_tracing_disabled.md")
  tags          = merge(local.apigateway_common_tags, { class = "unused" })

  param "items" {
    type = list(object({
      title         = string
      rest_api_id   = string
      stage_name     = string
      region        = string
      cred          = string
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
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_verbose
    notifier = notifier[param.notifier]
    text     = "Detected ${length(param.items)} elastic IP addresses unattached."
  }

  step "transform" "items_by_id" {
    value = { for row in param.items : row.stage_name => row }

    output "debug" {
      value = param.approvers
    }
  }

  step "pipeline" "correct_item" {
    for_each        = step.transform.items_by_id.value
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_apigateway_rest_api_stage_if_xray_tracing_disabled
    args = {
      title              = each.value.title
      rest_api_id        = each.value.rest_api_id
      stage_name         = each.value.stage_name
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

pipeline "correct_one_apigateway_rest_api_stage_if_xray_tracing_disabled" {
  title         = "Correct one VPC EIP if unattached"
  description   = "Runs corrective action on one EIP (Elastic IP addresses) which is unattached."
  // documentation = file("./apigateway/docs/correct_one_apigateway_rest_api_stage_if_xray_tracing_disabled.md")
  tags          = merge(local.apigateway_common_tags, { class = "unused" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "rest_api_id" {
    type        = string
    description = "The ID representing the allocation of the address for use with EC2-VPC."
  }

  param "stage_name" {
    type        = string
    description = "The ID representing the allocation of the address for use with EC2-VPC."
  }

  param "region" {
    type        = string
    description = local.description_region
    default     = "us-east-1"
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
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stage_if_xray_tracing_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected elastic IP address ${param.title} unattached."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label         = "Skip"
          value         = "skip"
          style         = local.style_info
          pipeline_ref  = local.pipeline_optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped elastic IP address ${param.title} unattached."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_xray_tracing" = {
          label         = "Enable xray tracing"
          value         = "enable_xray_tracing"
          style         = local.style_ok
          pipeline_ref  = local.aws_pipeline_modify_apigateway_rest_api_stage
          pipeline_args = {
            rest_api_id  = param.rest_api_id
            stage_name    = param.stage_name
            region        = param.region
            cred          = param.cred
          }
          success_msg = "Released elastic IP address ${param.title}."
          error_msg   = "Error releasing elastic IP address ${param.title}."
        }
      }
    }
  }
}

variable "apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "apigateway_rest_api_stage_if_xray_tracing_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "The schedule on which to run the trigger if enabled."
}

variable "apigateway_rest_api_stage_if_xray_tracing_disabled_default_action" {
  type        = string
  description = "The default action to use for the detected item, used if no input is provided."
  default     = "notify"
}

variable "apigateway_rest_api_stage_if_xray_tracing_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions to provide to approvers for selection."
  default     = ["skip", "enable_xray_tracing"]
}