# TODO: Convert remaining controls and remove use of pipeline key when looping
locals {
  cis_v300_1_control_mapping = {
    cis_v300_1_1  = {pipeline = pipeline.cis_v300_1_1 }
    cis_v300_1_2  = {pipeline = pipeline.cis_v300_1_2 }
    cis_v300_1_3  = {pipeline = pipeline.cis_v300_1_3 }
    cis_v300_1_4  = {pipeline = pipeline.cis_v300_1_4 }
    cis_v300_1_5  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.5 is a manual control."}}
    cis_v300_1_6  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.6 is a manual control."}}
    cis_v300_1_7  = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.7 is a manual control."}}
    cis_v300_1_8  = {pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_min_length_14, additional_args = {}}
    cis_v300_1_9  = {pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_password_reuse_24, additional_args = {}}
    cis_v300_1_10 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.10 is a manual control."}}
    cis_v300_1_11 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.11 is a manual control."}}
    cis_v300_1_12 = {pipeline = pipeline.detect_and_correct_iam_users_with_unused_credential_45_days, additional_args = {}}
    cis_v300_1_13 = {pipeline = pipeline.detect_and_delete_extra_iam_user_active_keys, additional_args = {}}
    cis_v300_1_14 = {pipeline = pipeline.detect_and_deactivate_iam_users_with_unused_credential_90_days, additional_args = {}}
    cis_v300_1_15 = {pipeline = pipeline.detect_and_delete_iam_user_inline_policies, additional_args = {}}
    cis_v300_1_16 = {pipeline = pipeline.detect_and_detach_iam_entities_with_policy_star_star, additional_args = {}}
    cis_v300_1_17 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.17 is a manual control."}}
    cis_v300_1_18 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.18 is a manual control."}}
    cis_v300_1_19 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.19 is a manual control."}}
    cis_v300_1_20 = {pipeline = pipeline.detect_and_correct_iam_access_analyzer_disabled_in_regions, additional_args = {}}
    cis_v300_1_21 = {pipeline = pipeline.manual_control, additional_args = {message = "CIS v3.0.0 1.21 is a manual control."}}
    cis_v300_1_22 = {pipeline = pipeline.detect_and_detach_iam_entities_with_cloudshell_fullaccess_policy, additional_args = {}}
  }
}

variable "cis_v300_1_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 1 pipelines to enable."

  default = [
    "cis_v300_1_1",
    "cis_v300_1_2",
    "cis_v300_1_3",
    "cis_v300_1_4",
    /*
    "cis_v300_1_5",
    "cis_v300_1_6",
    "cis_v300_1_7",
    "cis_v300_1_8",
    "cis_v300_1_9",
    "cis_v300_1_10",
    "cis_v300_1_11",
    "cis_v300_1_12",
    "cis_v300_1_13",
    "cis_v300_1_14",
    "cis_v300_1_15",
    "cis_v300_1_16",
    "cis_v300_1_17",
    "cis_v300_1_18",
    "cis_v300_1_19",
    "cis_v300_1_20",
    "cis_v300_1_21",
    "cis_v300_1_22"
    */
  ]
}

pipeline "cis_v300_1_1" {
  title         = "1.1 Maintain current contact details"
  #documentation = file("./cis_v300/docs/cis_v300_1_1.md")

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

  step "message" "header" {
    notifier = notifier[param.notifier]
    text     = "1.1 Maintain current contact details"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.manual_control

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_2" {
  title         = "1.2 Ensure security contact information is registered"
  #documentation = file("./cis_v300/docs/cis_v300_1_2.md")

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

  step "message" "header" {
    notifier = notifier[param.notifier]
    text     = "1.2 Ensure security contact information is registered"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_accounts_without_alternate_security_contact

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_3" {
  title         = "1.3 Ensure security questions are registered in the AWS account"
  #documentation = file("./cis_v300/docs/cis_v300_1_3.md")

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

  step "message" "header" {
    notifier = notifier[param.notifier]
    text     = "1.3 Ensure security questions are registered in the AWS account"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.manual_control

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_4" {
  title         = "1.4 Ensure no 'root' user account access key exists"
  #documentation = file("./cis_v300/docs/cis_v300_1_4.md")

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

  step "message" "header" {
    notifier = notifier[param.notifier]
    text     = "1.4 Ensure no 'root' user account access key exists"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_delete_iam_root_access_keys

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
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

  step "message" "header" {
    notifier = notifier[param.notifier]
    text     = "1 Identity and Access Management"
  }

  step "pipeline" "run_pipelines" {
    depends_on = [step.message.header]

    loop {
      until = (loop.index >= (length(var.cis_v300_1_enabled_pipelines)-1))
    }

    pipeline = local.cis_v300_1_control_mapping[var.cis_v300_1_enabled_pipelines[loop.index]].pipeline
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}
