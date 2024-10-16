locals {
  cis_v300_1_control_mapping = {
    cis_v300_1_1  = pipeline.cis_v300_1_1
    cis_v300_1_2  = pipeline.cis_v300_1_2
    cis_v300_1_3  = pipeline.cis_v300_1_3
    cis_v300_1_4  = pipeline.cis_v300_1_4
    cis_v300_1_5  = pipeline.cis_v300_1_5
    cis_v300_1_6  = pipeline.cis_v300_1_6
		cis_v300_1_7  = pipeline.cis_v300_1_7
		cis_v300_1_8  = pipeline.cis_v300_1_8
		cis_v300_1_9  = pipeline.cis_v300_1_9
		cis_v300_1_10 = pipeline.cis_v300_1_10
		cis_v300_1_11 = pipeline.cis_v300_1_11
		cis_v300_1_12 = pipeline.cis_v300_1_12
		cis_v300_1_13 = pipeline.cis_v300_1_13
		cis_v300_1_14 = pipeline.cis_v300_1_14
		cis_v300_1_15 = pipeline.cis_v300_1_15
		cis_v300_1_16 = pipeline.cis_v300_1_16
		cis_v300_1_17 = pipeline.cis_v300_1_17
		cis_v300_1_18 = pipeline.cis_v300_1_18
		cis_v300_1_19 = pipeline.cis_v300_1_19
		cis_v300_1_20 = pipeline.cis_v300_1_20
		cis_v300_1_21 = pipeline.cis_v300_1_21
		cis_v300_1_22 = pipeline.cis_v300_1_22
  }
}

variable "cis_v300_1_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v3.0.0 section Identity and Access Management pipelines to enable."

  default = [
    "cis_v300_1_1",
    "cis_v300_1_2",
    "cis_v300_1_3",
    "cis_v300_1_4",
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
  ]

  enum = [
    "cis_v300_1_1",
    "cis_v300_1_2",
    "cis_v300_1_3",
    "cis_v300_1_4",
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
  ]
}

pipeline "cis_v300_1" {
  title         = "1 Monitoring"
  documentation = file("./cis_v300/docs/cis_v300_1.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "5 Networking"
  }

  step "pipeline" "cis_v300_4" {
    depends_on = [step.message.header]
    for_each   = var.cis_v300_1_enabled_pipelines
    pipeline   = local.cis_v300_1_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_1" {
  title         = "1.1 Maintain current contact detail"
  documentation = file("./cis_v300/docs/cis_v300_1_1.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.1 Maintain current contact detailsd"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_unauthorized_api_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_2" {
  title         = "1.2 Ensure security contact information is registeredd"
  documentation = file("./cis_v300/docs/cis_v300_1_2.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.2 Ensure security contact information is registered"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_console_login_mfa_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_3" {
  title         = "1.3 Ensure security questions are registered in the AWS accoun"
  documentation = file("./cis_v300/docs/cis_v300_1_3.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.3 Ensure security questions are registered in the AWS accoun"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_root_login

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
  documentation = file("./cis_v300/docs/cis_v300_1_4.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.4 Ensure no 'root' user account access key exists"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_iam_policy_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_5" {
  title         = "1.5 Ensure MFA is enabled for the 'root' user account"
  documentation = file("./cis_v300/docs/cis_v300_1_5.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.5 Ensure MFA is enabled for the 'root' user account"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_cloudtrail_configuration

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_6" {
  title         = "1.6 Ensure hardware MFA is enabled for the 'root' user account"
  documentation = file("./cis_v300/docs/cis_v300_1_6.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.6 Ensure hardware MFA is enabled for the 'root' user account"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_console_authentication_failure

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_7" {
  title         = "1.7 Eliminate use of the 'root' user for administrative and daily tasks"
  documentation = file("./cis_v300/docs/cis_v300_1_7.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.7 Eliminate use of the 'root' user for administrative and daily tasks"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_disable_or_delete_cmk

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_8" {
  title         = "1.8 Ensure IAM password policy requires minimum length of 14 or greater"
  documentation = file("./cis_v300/docs/cis_v300_1_8.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.8 Ensure IAM password policy requires minimum length of 14 or greater"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_bucket_policy_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_9" {
  title         = "1.9 Ensure IAM password policy prevents password reuse"
  documentation = file("./cis_v300/docs/cis_v300_1_9.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.9 Ensure IAM password policy prevents password reuse"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_config_configuration_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_10" {
  title         = "1.10 Ensure multi-factor authentication (MFA) is enabled for all IAM users that have a console password"
  documentation = file("./cis_v300/docs/cis_v300_1_10.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.10 Ensure multi-factor authentication (MFA) is enabled for all IAM users that have a console password"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_security_group_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_11" {
  title         = "1.11 Do not setup access keys during initial user setup for all IAM users that have a console password"
  documentation = file("./cis_v300/docs/cis_v300_1_11.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.11 Do not setup access keys during initial user setup for all IAM users that have a console password"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_network_acl_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_12" {
  title         = "1.12 Ensure credentials unused for 45 days or greater are disabled"
  documentation = file("./cis_v300/docs/cis_v300_1_12.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.12 Ensure credentials unused for 45 days or greater are disabled"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_network_gateway_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_13" {
  title         = "1.13 Ensure there is only one active access key available for any single IAM user"
  documentation = file("./cis_v300/docs/cis_v300_1_13.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.13 Ensure there is only one active access key available for any single IAM user"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_route_table_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_14" {
  title         = "1.14 Ensure access keys are rotated every 90 days or less"
  documentation = file("./cis_v300/docs/cis_v300_1_14.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.14 Ensure access keys are rotated every 90 days or lessd"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_vpc_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_15" {
  title         = "1.15 Ensure IAM Users Receive Permissions Only Through Groups"
  documentation = file("./cis_v300/docs/cis_v300_1_15.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.15 Ensure IAM Users Receive Permissions Only Through Groups"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudwatch_log_groups_without_metric_filter_for_organization_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_16" {
  title         = "1.16 Ensure IAM policies that allow full \"*:*\" administrative privileges are not attached"
  documentation = file("./cis_v300/docs/cis_v300_1_16.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.16 Ensure IAM policies that allow full \"*:*\" administrative privileges are not attached"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_17" {
  title         = "1.17 Ensure a support role has been created to manage incidents with AWS Support"
  documentation = file("./cis_v300/docs/cis_v300_1_17.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.17 Ensure a support role has been created to manage incidents with AWS Support"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_18" {
  title         = "1.18 Ensure IAM instance roles are used for AWS resource access from instance"
  documentation = file("./cis_v300/docs/cis_v300_1_18.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.18 Ensure IAM instance roles are used for AWS resource access from instance"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_19" {
  title         = "1.19 Ensure that all the expired SSL/TLS certificates stored in AWS IAM are removed"
  documentation = file("./cis_v300/docs/cis_v300_1_19.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.19 Ensure that all the expired SSL/TLS certificates stored in AWS IAM are removed"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_20" {
  title         = "1.20 Ensure that IAM Access analyzer is enabled for all regions"
  documentation = file("./cis_v300/docs/cis_v300_1_20.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.20 Ensure that IAM Access analyzer is enabled for all regions"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_21" {
  title         = "1.21 Ensure IAM users are managed centrally via identity federation or AWS Organizations for multi-account environments"
  documentation = file("./cis_v300/docs/cis_v300_1_21.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.21 Ensure IAM users are managed centrally via identity federation or AWS Organizations for multi-account environments"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_1_22" {
  title         = "1.22 Ensure access to AWSCloudShellFullAccess is restricted"
  documentation = file("./cis_v300/docs/cis_v300_1_22.md")

  tags = {
    type = "terminal"
  }

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

  step "message" "header" {
    notifier = param.notifier
    text     = "1.22 Ensure access to AWSCloudShellFullAccess is restricted"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_security_hub_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}