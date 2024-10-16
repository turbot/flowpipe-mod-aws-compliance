locals {
  cis_v300_4_control_mapping = {
    cis_v300_4_1  = pipeline.cis_v300_4_1
    cis_v300_4_2  = pipeline.cis_v300_4_2
    cis_v300_4_3  = pipeline.cis_v300_4_3
    cis_v300_4_4  = pipeline.cis_v300_4_4
    cis_v300_4_5  = pipeline.cis_v300_4_5
    cis_v300_4_6  = pipeline.cis_v300_4_6
    cis_v300_4_7  = pipeline.cis_v300_4_7
    cis_v300_4_8  = pipeline.cis_v300_4_8
    cis_v300_4_9  = pipeline.cis_v300_4_9
    cis_v300_4_10 = pipeline.cis_v300_4_10
    cis_v300_4_11 = pipeline.cis_v300_4_11
    cis_v300_4_12 = pipeline.cis_v300_4_12
    cis_v300_4_13 = pipeline.cis_v300_4_13
    cis_v300_4_14 = pipeline.cis_v300_4_14
    cis_v300_4_15 = pipeline.cis_v300_4_15
    cis_v300_4_16 = pipeline.cis_v300_4_16
  }
}

variable "cis_v300_4_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 4 pipelines to enable."

  default = [
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

  enum = [
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

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    for_each   = var.cis_v300_4_enabled_pipelines
    pipeline   = local.cis_v300_4_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_4_1" {
  title         = "4.1 Ensure unauthorized API calls are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.1 Ensure unauthorized API calls are monitored"
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

pipeline "cis_v300_4_2" {
  title         = "4.2 Ensure management console sign-in without MFA is monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_2.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.2 Ensure management console sign-in without MFA is monitored"
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

pipeline "cis_v300_4_3" {
  title         = "4.3 Ensure usage of 'root' account is monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_3.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.3 Ensure usage of 'root' account is monitored"
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

pipeline "cis_v300_4_4" {
  title         = "4.4 Ensure IAM policy changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_4.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.4 Ensure IAM policy changes are monitored"
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

pipeline "cis_v300_4_5" {
  title         = "4.5 Ensure CloudTrail configuration changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_5.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.5 Ensure CloudTrail configuration changes are monitored"
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

pipeline "cis_v300_4_6" {
  title         = "4.6 Ensure AWS Management Console authentication failures are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_6.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.6 Ensure AWS Management Console authentication failures are monitored"
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

pipeline "cis_v300_4_7" {
  title         = "4.7 Ensure disabling or scheduled deletion of customer created CMKs is monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_7.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.7 Ensure disabling or scheduled deletion of customer created CMKs is monitored"
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

pipeline "cis_v300_4_8" {
  title         = "4.8 Ensure S3 bucket policy changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_8.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.8 Ensure S3 bucket policy changes are monitored"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_accounts_without_metric_filter_for_bucket_policy_changes

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_4_9" {
  title         = "4.9 Ensure AWS Config configuration changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_9.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.9 Ensure AWS Config configuration changes are monitored"
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

pipeline "cis_v300_4_10" {
  title         = "4.10 Ensure security group changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_10.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.10 Ensure security group changes are monitored"
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

pipeline "cis_v300_4_11" {
  title         = "4.11 Ensure Network Access Control Lists (NACL) changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_11.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.11 Ensure Network Access Control Lists (NACL) changes are monitored"
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

pipeline "cis_v300_4_12" {
  title         = "4.12 Ensure changes to network gateways are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_12.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.12 Ensure changes to network gateways are monitored"
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

pipeline "cis_v300_4_13" {
  title         = "4.13 Ensure route table changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_13.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.13 Ensure route table changes are monitored"
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

pipeline "cis_v300_4_14" {
  title         = "4.14 Ensure VPC changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_14.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.14 Ensure VPC changes are monitored"
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

pipeline "cis_v300_4_15" {
  title         = "4.15 Ensure AWS Organizations changes are monitored"
  documentation = file("./cis_v300/docs/cis_v300_4_15.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.15 Ensure AWS Organizations changes are monitored"
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

pipeline "cis_v300_4_16" {
  title         = "4.16 Ensure AWS Security Hub is enabled"
  documentation = file("./cis_v300/docs/cis_v300_4_16.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/4 Monitoring"
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
    text     = "4.16 Ensure AWS Security Hub is enabled"
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
