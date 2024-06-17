locals {
  // cis_v300_2_common_tags = merge(local.cis_v300_common_tags, {
  //   cis_section_id = "5"
  // })

  cis_v300_2_control_mapping = {
    cis_v300_2_1_1  = {pipeline = pipeline.detect_and_correct_s3_buckets_without_ssl_enforcement, additional_args = {}}
    cis_v300_2_1_2  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 2.1.2 is a manual control."}}
    cis_v300_2_1_3  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 2.1.3 is a TODO control."}}
    cis_v300_2_1_4  = {pipeline = pipeline.detect_and_correct_s3_buckets_if_publicly_accessible, additional_args = {}}
    cis_v300_2_2_1  = {pipeline = pipeline.detect_and_correct_ebs_volumes_with_encryption_at_rest_disabled, additional_args = {}}
    cis_v300_2_3_1  = {pipeline = pipeline.detect_and_correct_rds_db_instances_with_encryption_at_rest_disabled, additional_args = {}}
    cis_v300_2_3_2  = {pipeline = pipeline.detect_and_correct_rds_db_instances_with_auto_minor_version_upgrade_disabled, additional_args = {}}
    cis_v300_2_3_3  = {pipeline = pipeline.detect_and_correct_rds_db_instances_with_public_access_enabled, additional_args = {}}
    cis_v300_2_4_1  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 2.4.1 is a TODO control."}}  
  }
}

variable "cis_v300_2_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 2 controls to enable"
  default     = [
    "cis_v300_2_1_1", 
    "cis_v300_2_1_2",
    "cis_v300_2_1_3",
    "cis_v300_2_1_4",
    "cis_v300_2_2_1",
    "cis_v300_2_3_1",
    "cis_v300_2_3_2",
    "cis_v300_2_3_3",
    "cis_v300_2_4_1"
  ]
}


pipeline "cis_v300_2" {
  title         = "2 Storage"
  documentation = file("./cis_v300/docs/cis_v300_2.md")

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

  step "message" "cis_v300_2" {
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Section 2: Storage"
  }

  step "pipeline" "cis_v300_2" {
    loop {
      until = loop.index >= (length(var.cis_v300_2_enabled_controls)-1)
    }

    pipeline = local.cis_v300_2_control_mapping[var.cis_v300_2_enabled_controls[loop.index]].pipeline
    args     = merge({
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    },local.cis_v300_2_control_mapping[var.cis_v300_2_enabled_controls[loop.index]].additional_args)
  }

  // tags = merge(local.cis_v300_2_common_tags, {
  //   service = "AWS/VPC"
  // })
}
