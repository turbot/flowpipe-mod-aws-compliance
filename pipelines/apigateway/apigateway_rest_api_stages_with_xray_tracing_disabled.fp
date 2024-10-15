locals {
  apigateway_rest_api_stages_with_xray_tracing_disabled_query = <<-EOQ
  select
    concat(rest_api_id, ' [', '/', account_id, '/', region, ']') as title,
    rest_api_id,
    name as stage_name,
    region,
    sp_connection_name as conn
  from
    aws_api_gateway_stage
  where
    not tracing_enabled;
  EOQ
}

variable "apigateway_rest_api_stages_with_xray_tracing_disabled_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."
}

variable "apigateway_rest_api_stages_with_xray_tracing_disabled_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."
}

variable "apigateway_rest_api_stages_with_xray_tracing_disabled_default_action" {
  type        = string
  description = "The default action to use for detected items."
  default     = "notify"
}

variable "apigateway_rest_api_stages_with_xray_tracing_disabled_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enable_xray_tracing"]
}

trigger "query" "detect_and_correct_apigateway_rest_api_stages_with_xray_tracing_disabled" {
  title         = "Detect & correct API Gateway rest API stages with x-ray tracing disabled"
  description   = "Detect API Gateway rest API stages with x-ray tracing disabled and then skip or enable x-ray tracing."

  enabled  = var.apigateway_rest_api_stages_with_xray_tracing_disabled_trigger_enabled
  schedule = var.apigateway_rest_api_stages_with_xray_tracing_disabled_trigger_schedule
  database = var.database
  sql      = local.apigateway_rest_api_stages_with_xray_tracing_disabled_query

  capture "insert" {
    pipeline = pipeline.correct_apigateway_rest_api_stages_with_xray_tracing_disabled
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_apigateway_rest_api_stages_with_xray_tracing_disabled" {
  title         = "Detect & correct API Gateway rest API stages with x-ray tracing disabled"
  description   = "Detect API Gateway rest API stages with x-ray tracing disabled and then skip or enable x-ray tracing."
  

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
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.apigateway_rest_api_stages_with_xray_tracing_disabled_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_apigateway_rest_api_stages_with_xray_tracing_disabled
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

pipeline "correct_apigateway_rest_api_stages_with_xray_tracing_disabled" {
  title         = "Correct API Gateway rest API stages with x-ray tracing disabled"
  description   = "Enable x-ray tracing for API Gateway rest API stages with x-ray tracing disabled."
  

  param "items" {
    type = list(object({
      title         = string
      rest_api_id   = string
      stage_name    = string
      region        = string
      conn          = string
    }))
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
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} API Gateway rest API stage(s) with x-ray tracing disabled."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.stage_name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_apigateway_rest_api_stage_with_xray_tracing_disabled
    args = {
      title              = each.value.title
      rest_api_id        = each.value.rest_api_id
      stage_name         = each.value.stage_name
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_apigateway_rest_api_stage_with_xray_tracing_disabled" {
  title         = "Correct API Gateway rest API stage x-ray tracing disabled"
  description   = "Enable x-ray tracing for API Gateway rest API stage with x-ray tracing disabled."
  

  param "title" {
    type        = string
    description = local.description_title
  }

  param "rest_api_id" {
    type        = string
    description = "The ID of the REST API to be used with AWS API Gateway."
  }

  param "stage_name" {
    type        = string
    description = "The name of the stage within the AWS API Gateway."
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
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.apigateway_rest_api_stages_with_xray_tracing_disabled_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected API Gateway rest API stage ${param.title} with x-ray tracing disabled."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label         = "Skip"
          value         = "skip"
          style         = local.style_info
          pipeline_ref  = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped API Gateway rest API stage ${param.title}."
          }
          success_msg = ""
          error_msg   = ""
        },
        "enable_xray_tracing" = {
          label         = "Enable xray tracing"
          value         = "enable_xray_tracing"
          style         = local.style_ok
          pipeline_ref  = aws.pipeline.modify_apigateway_rest_api_stage
          pipeline_args = {
            rest_api_id   = param.rest_api_id
            stage_name    = param.stage_name
            region        = param.region
            conn          = param.conn
          }
          success_msg = "Enabled x-ray tracing for API Gateway rest API stage ${param.title}."
          error_msg   = "Error enabling x-ray tracing for API Gateway rest API stage ${param.title}."
        }
      }
    }
  }
}

