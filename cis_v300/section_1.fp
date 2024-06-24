locals {
  // cis_v300_1_common_tags = merge(local.cis_v300_common_tags, {
  //   cis_section_id = "1"
  // })
  cis_v300_1_control_mapping = {
    cis_v300_1_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.1 is a manual control."}}
    cis_v300_1_2  = {pipeline = pipeline.detect_and_correct_account_alternate_contact_security_registered, additional_args = {}}
    cis_v300_1_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.3 is a manual control."}}
    cis_v300_1_4  = {pipeline = pipeline.detect_and_delete_iam_root_access_keys, additional_args = {}}
    cis_v300_1_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.5 is a manual control."}}
    cis_v300_1_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.6 is a manual control."}}
    cis_v300_1_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.7 is a manual control."}}
    cis_v300_1_8  = {pipeline = pipeline.detect_and_correct_iam_account_password_policy_no_min_length_14, additional_args = {}}
    cis_v300_1_9  = {pipeline = pipeline.detect_and_correct_iam_account_password_policy_no_policy_reuse_24, additional_args = {}}
    cis_v300_1_10 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.10 is a manual control."}}
    cis_v300_1_11 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.11 is a manual control."}}
    cis_v300_1_12 = {pipeline = pipeline.detect_and_deactivate_iam_user_unused_credentials_45, additional_args = {}}
    cis_v300_1_13 = {pipeline = pipeline.detect_and_delete_extra_iam_user_active_keys, additional_args = {}}
    cis_v300_1_14 = {pipeline = pipeline.detect_and_deactivate_iam_user_unused_credentials_90, additional_args = {}}
    cis_v300_1_15 = {pipeline = pipeline.detect_and_delete_iam_user_inline_policies, additional_args = {}}
    cis_v300_1_16 = {pipeline = pipeline.detect_and_detach_iam_entities_with_policy_star_star, additional_args = {}}
    cis_v300_1_17 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.17 is a manual control."}}
    cis_v300_1_18 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.18 is a manual control."}}
    cis_v300_1_19 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.19 is a manual control."}}
    cis_v300_1_20 = {pipeline = pipeline.detect_and_enable_iam_accessanalyzer_analyzer_disabled, additional_args = {}}
    cis_v300_1_21 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.21 is a manual control."}}
    cis_v300_1_22 = {pipeline = pipeline.detect_and_detach_iam_entities_with_cloudshell_fullaccess_policy, additional_args = {}}
  }
}

variable "cis_v300_1_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 1 controls to enable"
  default     = [
    "cis_v300_1_2", 
    "cis_v300_1_4",
    "cis_v300_1_8",
    "cis_v300_1_9",
    "cis_v300_1_12",
    "cis_v300_1_13",
    "cis_v300_1_14",
    "cis_v300_1_15",
    "cis_v300_1_16",
    "cis_v300_1_20",
    "cis_v300_1_22"
  ]
}

pipeline "cis_v300_1" {
  title         = "1 Identity and Access Management"
  documentation = file("./cis_v300/docs/cis_v300_1.md")

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
    subject  = "Request to run CIS v3.0.0 Section 1: Identity and Access Management?"
    prompt   = "Do you wish to run CIS v3.0.0 Section 1: Identity and Access Management?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v300_1" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 1: Identity and Access Management"
  }

  step "pipeline" "cis_v300_1" {
    depends_on = [step.message.cis_v300_1]
    if         = (step.transform.input_value.value == "yes")

    loop {
      until = (loop.index >= (length(var.cis_v300_1_enabled_controls)-1))
    }

    pipeline = local.cis_v300_1_control_mapping[var.cis_v300_1_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v300_1_control_mapping[var.cis_v300_1_enabled_controls[loop.index]].additional_args)
  }
}