// locals {
//   ec2_launch_templates_with_public_ips_query = <<-EOQ
//     with public_launch_templates as (
//       select
//         i.tags ->> 'aws:ec2launchtemplate:id' as public_launch_template_id
//       from
//         aws_ec2_instance as i,
//         jsonb_array_elements(launch_template_data -> 'NetworkInterfaces') as nic
//       where
//         (nic -> 'AssociatePublicIpAddress')::bool
//     ),
//     launch_templates_associated_instance as (
//       select
//         distinct tags ->> 'aws:ec2launchtemplate:id' as launch_template_id
//       from
//         aws_ec2_instance
//     )
//     select
//       concat(t.launch_template_id, ' [', t.region, '/', t.account_id, ']') as title,
//       t.launch_template_id,
//       t.region,
//       t._ctx ->> 'connection_name' as cred
//     from
//       aws_ec2_launch_template as t
//       left join launch_templates_associated_instance as i on i.launch_template_id = t.launch_template_id
//     where
//       i.launch_template_id is not null
//       and t.launch_template_id in (select public_launch_template_id from public_launch_templates);
//   EOQ
// }

// trigger "query" "detect_and_correct_ec2_launch_templates_with_public_ips" {
//   title         = "Detect & correct EC2 Launch Templates with public IPs"
//   description   = "Detects EC2 Launch Templates that automatically assign public IPs to network interfaces and executes the chosen action."
//   // documentation = file("./ec2/docs/detect_and_correct_ec2_launch_templates_with_public_ips_trigger.md")
//   tags          = merge(local.ec2_common_tags, { class = "configuration" })

//   enabled  = var.ec2_launch_templates_with_public_ips_trigger_enabled
//   schedule = var.ec2_launch_templates_with_public_ips_trigger_schedule
//   database = var.database
//   sql      = local.ec2_launch_templates_with_public_ips_query

//   capture "insert" {
//     pipeline = pipeline.correct_ec2_launch_templates_with_public_ips
//     args = {
//       items = self.inserted_rows
//     }
//   }
// }

// pipeline "detect_and_correct_ec2_launch_templates_with_public_ips" {
//   title         = "Detect & correct EC2 Launch Templates with public IPs"
//   description   = "Detects EC2 Launch Templates that automatically assign public IPs and performs the chosen action."
//   // documentation = file("./ec2/docs/detect_and_correct_ec2_launch_templates_with_public_ips.md")
//   tags          = merge(local.ec2_common_tags, { class = "configuration", type = "featured" })

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
//     default     = var.ec2_launch_templates_with_public_ips_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_launch_templates_with_public_ips_enabled_actions
//   }

//   step "query" "detect" {
//     database = param.database
//     sql      = local.ec2_launch_templates_with_public_ips_query
//   }

//   step "pipeline" "respond" {
//     pipeline = pipeline.correct_ec2_launch_templates_with_public_ips
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

// pipeline "correct_ec2_launch_templates_with_public_ips" {
//   title         = "Correct EC2 Launch Templates with public IPs"
//   description   = "Executes corrective actions on EC2 Launch Templates to disable automatic public IP assignment."
//   // documentation = file("./ec2/docs/correct_ec2_launch_templates_with_public_ips.md")
//   tags          = merge(local.ec2_common_tags, { class = "configuration" })

//   param "items" {
//     type = list(object({
//       title                 = string,
//       launch_template_id    = string,
//       region                = string,
//       cred                  = string,
//       public_ip_association = string
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
//     default     = var.ec2_launch_templates_with_public_ips_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_launch_templates_with_public_ips_enabled_actions
//   }

//   step "message" "notify_detection_count" {
//     if       = var.notification_level == local.level_verbose
//     notifier = notifier[param.notifier]
//     text     = "Detected ${length(param.items)} EC2 launch templates with public IPs."
//   }

//   step "transform" "items_by_id" {
//     value = { for row in param.items : row.launch_template_id => row }
//   }

//   step "pipeline" "correct_item" {
//     for_each        = step.transform.items_by_id.value
//     max_concurrency = var.max_concurrency
//     pipeline        = pipeline.correct_one_ec2_launch_template_with_public_ips
//     args = {
//       title                = each.value.title,
//       launch_template_id   = each.value.launch_template_id,
//       region               = each.value.region,
//       cred                 = each.value.cred,
//       notifier             = param.notifier,
//       notification_level   = param.notification_level,
//       approvers            = param.approvers,
//       default_action       = param.default_action,
//       enabled_actions      = param.enabled_actions
//     }
//   }
// }

// pipeline "correct_one_ec2_launch_template_with_public_ips" {
//   title         = "Correct one EC2 Launch Template with public IPs"
//   description   = "Runs corrective action to disable automatic public IP assignment on an EC2 Launch Template."
//   // documentation = file("./ec2/docs/correct_one_ec2_launch_template_with_public_ips.md")
//   tags          = merge(local.ec2_common_tags, { class = "configuration" })

//   param "title" {
//     type        = string
//     description = local.description_title
//   }

//   param "launch_template_id" {
//     type        = string
//     description = "The ID of the EC2 Launch Template."
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
//     default     = var.ec2_launch_templates_with_public_ips_default_action
//   }

//   param "enabled_actions" {
//     type        = list(string)
//     description = local.description_enabled_actions
//     default     = var.ec2_launch_templates_with_public_ips_enabled_actions
//   }

//   step "pipeline" "disable_public_ip" {
//     pipeline = aws_pipeline_modify_launch_template
//     args = {
//       launch_template_id    = param.launch_template_id,
//       associate_public_ip   = "false", // Set to 'false' to disable automatic public IP assignment
//       region                = param.region,
//       cred                  = param.cred
//     }
//   }
// }

// variable "ec2_launch_templates_with_public_ips_trigger_enabled" {
//   type        = bool
//   default     = false
//   description = "If true, the trigger is enabled."
// }

// variable "ec2_launch_templates_with_public_ips_trigger_schedule" {
//   type        = string
//   default     = "1h"
//   description = "The schedule on which to run the trigger if enabled."
// }

// variable "ec2_launch_templates_with_public_ips_default_action" {
//   type        = string
//   default     = "notify"
//   description = "The default action to use for the detected item, used if no input is provided."
// }

// variable "ec2_launch_templates_with_public_ips_enabled_actions" {
//   type        = list(string)
//   default     = ["disable_public_ip"]
//   description = "The list of enabled actions to provide for selection."
// }
