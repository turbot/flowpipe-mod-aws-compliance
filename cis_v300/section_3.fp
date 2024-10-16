locals {
  cis_v300_3_control_mapping = {
    cis_v300_3_1  = pipeline.cis_v300_3_1
    cis_v300_3_2  = pipeline.cis_v300_3_2
    cis_v300_3_3  = pipeline.cis_v300_3_3
    cis_v300_3_4  = pipeline.cis_v300_3_4
    cis_v300_3_5  = pipeline.cis_v300_3_5
    cis_v300_3_6  = pipeline.cis_v300_3_6
    cis_v300_3_7  = pipeline.cis_v300_3_7
    cis_v300_3_8  = pipeline.cis_v300_3_8
    cis_v300_3_9  = pipeline.cis_v300_3_9

  }
}

variable "cis_v300_3_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v3.0.0 section 3 pipelines to enable."

  default = [
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

  enum = [
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

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3 Logging"
  }

  step "pipeline" "cis_v300_3" {
    depends_on = [step.message.header]
    for_each   = var.cis_v300_3_enabled_pipelines
    pipeline   = local.cis_v300_3_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_1" {
  title         = "3.1 Ensure CloudTrail is enabled in all regions"
  documentation = file("./cis_v300/docs/cis_v300_3_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.1 Ensure CloudTrail is enabled in all regions"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_vpc_network_acls_allowing_ingress_to_remote_server_administration_ports

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_2" {
  title         = "3.2 Ensure CloudTrail log file validation is enabled"
  documentation = file("./cis_v300/docs/cis_v300_5_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.2 Ensure CloudTrail log file validation is enabled"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudtrail_trails_with_log_file_validation_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_3" {
  title         = "3.3 Ensure AWS Config is enabled in all regions"
  documentation = file("./cis_v300/docs/cis_v300_3_3.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.3 Ensure AWS Config is enabled in all regions"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_config_disabled_in_regions

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_4" {
  title         = "3.4 Ensure S3 bucket access logging is enabled on the CloudTrail S3 bucket"
  documentation = file("./cis_v300/docs/cis_v300_3_4.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.4 Ensure S3 bucket access logging is enabled on the CloudTrail S3 bucket"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudtrail_trails_with_s3_logging_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_5" {
  title         = "3.5 Ensure CloudTrail logs are encrypted at rest using KMS CMKs"
  documentation = file("./cis_v300/docs/cis_v300_5_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.5 Ensure CloudTrail logs are encrypted at rest using KMS CMKs"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudtrail_trail_logs_not_encrypted_with_kms_cmk

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_6" {
  title         = "3.6 Ensure rotation for customer-created symmetric CMKs is enabled"
  documentation = file("./cis_v300/docs/cis_v300_3_6.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.6 Ensure rotation for customer-created symmetric CMKs is enabled"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_kms_keys_with_rotation_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_7" {
  title         = "3.7 Ensure VPC flow logging is enabled in all VPCs"
  documentation = file("./cis_v300/docs/cis_v300_3_7.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.7 Ensure VPC flow logging is enabled in all VPCs"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_vpcs_without_flow_logs

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_8" {
  title         = "3.8 Ensure that Object-level logging for write events is enabled for S3 bucket"
  documentation = file("./cis_v300/docs/cis_v300_3_8.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.8 Ensure that Object-level logging for write events is enabled for S3 bucket"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudtrail_trails_with_s3_object_level_logging_for_write_events_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v300_3_9" {
  title         = "3.9 Ensure that Object-level logging for read events is enabled for S3 bucket"
  documentation = file("./cis_v300/docs/cis_v300_3_7.md")

  tags = {
    type   = "terminal"
    folder = "CIS v3.0.0/3 Logging"
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
    text     = "3.9 Ensure that Object-level logging for read events is enabled for S3 bucket"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_cloudtrail_trails_with_s3_object_level_logging_for_read_events_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}
