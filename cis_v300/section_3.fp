locals {
  // cis_v300_5_common_tags = merge(local.cis_v300_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v300_3_control_mapping = {
    cis_v300_3_1  = {pipeline = pipeline.detect_and_correct_cloudtrail_trail_multi_region_read_write_disabled, additional_args = {}}
    cis_v300_3_2  = {pipeline = pipeline.detect_and_correct_cloudtrail_trails_log_file_validation_disabled, additional_args = {}}
    cis_v300_3_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 3.3 is in the TODO list."}}
    cis_v300_3_4  = {pipeline = pipeline.detect_and_correct_cloudtrail_trails_with_s3_logging_disabled, additional_args = {}}
    cis_v300_3_5  = {pipeline = pipeline.detect_and_correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk, additional_args = {}}
    cis_v300_3_6  = {pipeline = pipeline.detect_and_correct_kms_keys_with_rotation_disabled, additional_args = {}}
    cis_v300_3_7  = {pipeline = pipeline.detect_and_correct_vpcs_without_flow_logs, additional_args = {}}
    cis_v300_3_8  = {pipeline = pipeline.detect_and_correct_cloudtrail_trails_with_s3_object_write_events_audit_disabled, additional_args = {}}
    cis_v300_3_9  = {pipeline = pipeline.detect_and_correct_cloudtrail_trails_with_s3_object_read_events_audit_disabled, additional_args = {}}
  }
}

variable "cis_v300_3_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 3 controls to enable"
  default     = [
    "cis_v300_3_1", 
    "cis_v300_3_2",
    "cis_v300_3_3",
    "cis_v300_3_4",
    "cis_v300_3_5",
    "cis_v300_3_6",
    "cis_v300_3_7",
    "cis_v300_3_8",
    "cis_v300_3_9"
  ]
}

pipeline "cis_v300_3" {
  title         = "3 Logging"
  documentation = file("./cis_v300/docs/cis_v300_3.md")

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
    subject  = "Request to run CIS v3.0.0 Section 3: Logging?"
    prompt   = "Do you wish to run CIS v3.0.0 Section 3: Logging?"
    options  = [
      {value = "no", label = "No", style = local.style_alert},
      {value = "yes", label = "Yes", style = local.style_ok}
    ]
  }

  step "transform" "input_value" {
    value = (length(param.approvers) > 0 ? step.input.should_run.value : "yes")
  }

  step "message" "cis_v300_3" {
    if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 3: Logging"
  }

  step "pipeline" "cis_v300_3" {
    depends_on = [step.message.cis_v300_3]
    if       = (step.transform.input_value.value == "yes")

    loop {
      until = loop.index >= (length(var.cis_v300_3_enabled_controls)-1)
    }

    pipeline = local.cis_v300_3_control_mapping[var.cis_v300_3_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v300_3_control_mapping[var.cis_v300_3_enabled_controls[loop.index]].additional_args)
  }
}
