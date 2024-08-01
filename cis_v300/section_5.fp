locals {
  // cis_v300_5_common_tags = merge(local.cis_v300_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v300_5_control_mapping = {
    cis_v300_5_1  = {pipeline = pipeline.detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports, additional_args = {}}
    cis_v300_5_2  = {pipeline = pipeline.detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports, additional_args = {}}
    cis_v300_5_3  = {pipeline = pipeline.detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_ipv6, additional_args = {}}
    cis_v300_5_4  = {pipeline = pipeline.detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_ipv4, additional_args = {}}
    cis_v300_5_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 5.5 is a manual control."}}
    cis_v300_5_6  = {pipeline = pipeline.detect_and_correct_ec2_instances_not_using_imdsv2, additional_args = {}}
  }
}

variable "cis_v300_5_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 5 controls to enable"
  default     = [
    "cis_v300_5_1", 
    "cis_v300_5_2",
    "cis_v300_5_3",
    "cis_v300_5_4",
    "cis_v300_5_5",
    "cis_v300_5_6"
  ]
}

pipeline "cis_v300_5" {
  title         = "5 Networking"
  documentation = file("./cis_v300/docs/cis_v300_5.md")

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

  step "input" "should_run" {
    if       = (length(param.approvers) > 0)
    notifier = notifier[param.notifier]
    type     = "button"
    subject  = "Request to run CIS v3.0.0 Section 5: Networking?"
    prompt   = "Do you wish to run CIS v3.0.0 Section 5: Networking?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v300_5" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 5: Networking"
  }

  step "pipeline" "cis_v300_5" {
    depends_on = [step.message.cis_v300_5]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v300_5_enabled_controls)-1)
    }

    pipeline = local.cis_v300_5_control_mapping[var.cis_v300_5_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v300_5_control_mapping[var.cis_v300_5_enabled_controls[loop.index]].additional_args)
  }

  // tags = merge(local.cis_v300_5_common_tags, {
  //   service = "AWS/VPC"
  // })
}
