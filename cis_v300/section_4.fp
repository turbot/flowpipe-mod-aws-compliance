locals {
  // cis_v300_4_common_tags = merge(local.cis_v300_common_tags, {
  //   cis_section_id = "4"
  // })

  cis_v300_4_control_mapping = {
    cis_v300_4_1  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_unauthorized_api_changes, additional_args = {}}
    cis_v300_4_2  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_console_login_mfa_changes, additional_args = {}}
    cis_v300_4_3  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_root_login, additional_args = {}}
    cis_v300_4_4  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_iam_changes, additional_args = {}}
    cis_v300_4_5  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_cloudtrail_configuration, additional_args = {}}
    cis_v300_4_6  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_console_authentication_failure, additional_args = {}}
    cis_v300_4_7  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_disable_or_delete_cmk, additional_args = {}}
    cis_v300_4_8  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_bucket_policy_changes, additional_args = {}}
    cis_v300_4_9  = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_config_configuration_changes, additional_args = {}}
    cis_v300_4_10 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_security_group_changes, additional_args = {}}
    cis_v300_4_11 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_network_acl_changes, additional_args = {}}
    cis_v300_4_12 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_network_gateway_changes, additional_args = {}}
    cis_v300_4_13 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes, additional_args = {}}
    cis_v300_4_14 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_vpc_changes, additional_args = {}}
    cis_v300_4_15 = {pipeline = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes, additional_args = {}}
    cis_v300_4_16 = {pipeline = pipeline.detect_and_correct_regions_with_security_hub_disabled, additional_args = {}}
  }
}

variable "cis_v300_4_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 4 controls to enable"
  default     = [
    "cis_v300_4_1",
    "cis_v300_4_2",
    "cis_v300_4_3",
    "cis_v300_4_4",
    "cis_v300_4_5",
    "cis_v300_4_6",
    "cis_v300_4_7",
    "cis_v300_4_8",
    "cis_v300_4_9",
    "cis_v300_4_10",
    "cis_v300_4_11",
    "cis_v300_4_12",
    "cis_v300_4_13",
    "cis_v300_4_14",
    "cis_v300_4_15",
    "cis_v300_4_16"
  ]
}

pipeline "cis_v300_4" {
  title         = "4 Monitoring"
  documentation = file("./cis_v300/docs/cis_v300_4.md")

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
    subject  = "Request to run CIS v3.0.0 Section 4: Monitoring?"
    prompt   = "Do you wish to run CIS v3.0.0 Section 4: Monitoring?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v300_4" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 4: Monitoring"
  }

  step "pipeline" "cis_v300_4" {
    depends_on = [step.message.cis_v300_4]
    if         = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v300_4_enabled_controls)-1)
    }

    pipeline = local.cis_v300_4_control_mapping[var.cis_v300_4_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v300_4_control_mapping[var.cis_v300_4_enabled_controls[loop.index]].additional_args)
  }

  // tags = merge(local.cis_v300_4_common_tags, {
  //   service = "AWS/VPC"
  // })
}
