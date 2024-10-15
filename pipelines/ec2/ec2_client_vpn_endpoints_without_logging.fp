// locals {
//   ec2_client_vpn_endpoints_without_logging_query = <<-EOQ
//     select
//       concat(client_vpn_endpoint_id, ' [', account_id, '/', region, ']') as title,
//       client_vpn_endpoint_id,
//       region,
//       _ctx ->> 'connection_name' as cred,
//       connection_log_options ->> 'Enabled' as logging_enabled
//     from
//       aws_ec2_client_vpn_endpoint
//     where
//       connection_log_options ->> 'Enabled' = 'false';
//   EOQ
// }

// trigger "query" "detect_and_correct_ec2_client_vpn_endpoints_without_logging" {
//   title         = "Detect & correct EC2 Client VPN endpoints without client connection logging"
//   description   = "Detects EC2 Client VPN endpoints without connection logging enabled and executes the chosen action."

//   tags          = merge(local.vpn_common_tags, { class = "compliance" })

//   enabled  = var.ec2_client_vpn_endpoints_without_logging_trigger_enabled
//   schedule = var.ec2_client_vpn_endpoints_without_logging_trigger_schedule
//   database = var.database
//   sql      = local.ec2_client_vpn_endpoints_without_logging_query

//   capture "insert" {
//     pipeline = pipeline.correct_ec2_client_vpn_endpoints_without_logging
//     args = {
//       items = self.inserted_rows
//     }
//   }
// }

// pipeline "detect_and_correct_ec2_client_vpn_endpoints_without_logging" {
//   title         = "Detect & correct EC2 Client VPN endpoints without client connection logging"
//   description   = "Detects EC2 Client VPN endpoints without connection logging enabled and performs the chosen action."

//   tags          = merge(local.vpn_common_tags, { class = "compliance", recommended = "true" })

//   param "database" {
//     type        = string
//     description = local.description_database
//     default     = var.database
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.ec2_client_vpn_endpoints_without_logging_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_client_vpn_endpoints_without_logging_enabled_actions
//   }

//   step "query" "detect" {
//     database = param.database
//     sql      = local.ec2_client_vpn_endpoints_without_logging_query
//   }

//   step "pipeline" "respond" {
//     pipeline = pipeline.correct_ec2_client_vpn_endpoints_without_logging
//     args = {
//       items              = step.query.detect.rows
//       notifier           = param.notifier
//       notification_level = param.notification_level
//       approvers          = param.approvers
//       default_action     = param.default_action
//       enabled_actions    = param.enabled_actions
//     }
//   }
// }

// pipeline "correct_ec2_client_vpn_endpoints_without_logging" {
//   title         = "Correct EC2 Client VPN endpoints without client connection logging"
//   description   = "Executes corrective actions on EC2 Client VPN endpoints to enable connection logging."

//   tags          = merge(local.vpn_common_tags, { class = "compliance" })

//   param "items" {
//     type = list(object({
//       title                  = string,
//       client_vpn_endpoint_id = string,
//       region                 = string,
//       cred                   = string,
//       logging_enabled        = string
//     }))
//     description = local.description_items
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.ec2_client_vpn_endpoints_without_logging_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_client_vpn_endpoints_without_logging_enabled_actions
//   }

//   step "message" "notify_detection_count" {
//     if       = var.notification_level == local.level_info
//     notifier = notifier[param.notifier]
//     text     = "Detected ${length(param.items)} EC2 Client VPN Endpoints."
//   }

//   step "transform" "items_by_id" {
//     value = { for row in param.items : row.client_vpn_endpoint_id => row }
//   }

//   step "pipeline" "correct_item" {
//     for_each        = step.transform.items_by_id.value
//     max_concurrency = var.max_concurrency
//     pipeline        = pipeline.correct_one_ec2_client_vpn_endpoint_without_logging
//     args = {
//       title                  = each.value.title,
//       client_vpn_endpoint_id = each.value.client_vpn_endpoint_id,
//       region                 = each.value.region,
//       cred                   = each.value.cred,
//       notifier               = param.notifier,
//       notification_level     = param.notification_level,
//       approvers              = param.approvers,
//       default_action         = param.default_action,
//       enabled_actions        = param.enabled_actions
//     }
//   }
// }

// pipeline "correct_one_ec2_client_vpn_endpoint_without_logging" {
//   title         = "Correct one EC2 Client VPN endpoint without client connection logging"
//   description   = "Runs corrective action to enable logging on a EC2 Client VPN endpoint."

//   tags          = merge(local.vpn_common_tags, { class = "compliance" })

//   param "title" {
//     type        = string
//     description = local.description_title
//   }

//   param "client_vpn_endpoint_id" {
//     type        = string
//     description = "The ID of the EC2 Client VPN endpoint."
//   }

//   param "region" {
//     type        = string
//     description = local.description_region
//   }

//   param "cred" {
//     type        = string
//     description = local.description_credential
//   }

//   param "notifier" {
//     type        = string
//     description = local.description_notifier
//     default     = var.notifier
//   }

//   param "notification_level" {
//     type        = string
//     description = local.description_notifier_level
//     default     = var.notification_level
//   }

//   param "approvers" {
//     type        = list(string)
//     description = local.description_approvers
//     default     = var.approvers
//   }

//   param "default_action" {
//     type        = string
//     description = local.description_default_action
//     default     = var.ec2_client_vpn_endpoints_without_logging_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_client_vpn_endpoints_without_logging_enabled_actions
//   }

//   step "pipeline" "enable_logging" {
//     pipeline = aws_pipeline_modify_vpn_endpoint_logging
//     args = {
//       client_vpn_endpoint_id = param.client_vpn_endpoint_id,
//       logging_enabled        = "true", // Set to 'true' to enable logging
//       region                 = param.region,
//       cred                   = param.cred
//     }
//   }
// }

// variable "ec2_client_vpn_endpoints_without_logging_trigger_enabled" {
//   type        = bool
//   default     = false
//   description = "If true, the trigger is enabled."
// }

// variable "ec2_client_vpn_endpoints_without_logging_trigger_schedule" {
//   type        = string
//   default     = "1h"
//   description = "If the trigger is enabled, run it on this schedule."
// }

// variable "ec2_client_vpn_endpoints_without_logging_default_action" {
//   type        = string
//   default     = "notify"
//   description = "The default action to use when there are no approvers."
// }

// variable "ec2_client_vpn_endpoints_without_logging_enabled_actions" {
//   type        = list(string)
//   default     = ["enable_logging"]
//   description = "The list of enabled actions to provide for selection."
// }

// variable "ec2_client_vpn_endpoints_without_logging_enabled_actions" {
//   type        = list(string)
//   default     = ["enable_logging"]
//   description = "The list of enabled actions to provide for selection."
// }
