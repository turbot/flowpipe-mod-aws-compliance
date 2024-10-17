locals {
  cis_v400_2_control_mapping = {
    cis_v400_2_1_1 = pipeline.cis_v400_2_1_1
    cis_v400_2_1_2 = pipeline.cis_v400_2_1_2
    cis_v400_2_1_3 = pipeline.cis_v400_2_1_3
    cis_v400_2_1_4 = pipeline.cis_v400_2_1_4
    cis_v400_2_2_1 = pipeline.cis_v400_2_2_1
    cis_v400_2_2_2 = pipeline.cis_v400_2_2_2
    cis_v400_2_2_3 = pipeline.cis_v400_2_2_3
    cis_v400_2_2_4 = pipeline.cis_v400_2_2_4
    cis_v400_2_3_1 = pipeline.cis_v400_2_3_1
  }
}

variable "cis_v400_2_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v4.0.0 section 2 pipelines to enable."

  default = [
    "cis_v400_2_1_1",
    "cis_v400_2_1_2",
    "cis_v400_2_1_3",
    "cis_v400_2_1_4",
    "cis_v400_2_2_1",
    "cis_v400_2_2_2",
    "cis_v400_2_2_3",
    "cis_v400_2_2_4",
    "cis_v400_2_3_1"
  ]

  enum = [
    "cis_v400_2_1_1",
    "cis_v400_2_1_2",
    "cis_v400_2_1_3",
    "cis_v400_2_1_4",
    "cis_v400_2_2_1",
    "cis_v400_2_2_2",
    "cis_v400_2_2_3",
    "cis_v400_2_2_4",
    "cis_v400_2_3_1"
  ]
}

pipeline "cis_v400_2" {
  title         = "2 Storage"
  documentation = file("./cis_v400/docs/cis_v400_2.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage"
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
    text     = "2 Storage"
  }

  step "pipeline" "cis_v400_2" {
    depends_on = [step.message.header]
    for_each   = var.cis_v400_2_enabled_pipelines
    pipeline   = local.cis_v400_2_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

/*
# TODO: Is there a way to include subsections without cyclic dependencies? Do we want them?
pipeline "cis_v400_2_1" {
  title         = "2.1 Simple Storage Service (S3)"
  #documentation = file("./cis_v400/docs/cis_v400_2_1.md")

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
    text     = "2.1 Simple Storage service (S3)"
  }

  step "pipeline" "run_pipelines" {
    depends_on = [step.message.header]
    for_each   = var.cis_v400_2_1_enabled_pipelines
    pipeline   = local.cis_v400_2_1_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}
*/

pipeline "cis_v400_2_1_1" {
  title         = "2.1.1 Ensure S3 Bucket Policy is set to deny HTTP requests"
  documentation = file("./cis_v400/docs/cis_v400_2_1_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.1 Simple Storage Service (S3)"
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
    text     = "2.1.1 Ensure S3 Bucket Policy is set to deny HTTP requests"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_s3_buckets_without_ssl_enforcement

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_1_2" {
  title         = "2.1.2 Ensure MFA Delete is enabled on S3 buckets"
  documentation = file("./cis_v400/docs/cis_v400_2_1_2.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.1 Simple Storage Service (S3)"
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
    text     = "2.1.2 Ensure MFA Delete is enabled on S3 buckets"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_s3_buckets_with_mfa_delete_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_1_3" {
  title         = "2.1.3 Ensure all data in Amazon S3 has been discovered, classified, and secured when necessary"
  documentation = file("./cis_v400/docs/cis_v400_2_1_3.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.1 Simple Storage Service (S3)"
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
    text     = "2.1.3 Ensure all data in Amazon S3 has been discovered, classified, and secured when necessary"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.manual_detection

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_1_4" {
  title          = "2.1.4 Ensure that S3 is configured with 'Block Public Access' enabled"
  documentation = file("./cis_v400/docs/cis_v400_2_1_4.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.1 Simple Storage Service (S3)"
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
    text     = "2.1.4 Ensure that S3 is configured with 'Block Public Access' enabled"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_s3_buckets_with_public_access_enabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_2_1" {
  title         = "2.2.1 Ensure that encryption-at-rest is enabled for RDS instances"
  documentation = file("./cis_v400/docs/cis_v400_2_2_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.2 Relational Database Service (RDS)"
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
    text     = "2.2.1 Ensure that encryption-at-rest is enabled for RDS instances"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_rds_db_instances_with_encryption_at_rest_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_2_2" {
  title         = "2.2.2 Ensure the Auto Minor Version Upgrade feature is enabled for RDS instances"
  documentation = file("./cis_v400/docs/cis_v400_2_2_2.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.2 Relational Database Service (RDS)"
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
    text     = "2.2.2 Ensure the Auto Minor Version Upgrade feature is enabled for RDS instances"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_rds_db_instances_with_auto_minor_version_upgrade_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_2_3" {
  title         = "2.2.3 Ensure that RDS instances are not publicly accessible"
  documentation = file("./cis_v400/docs/cis_v400_2_2_3.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.2 Relational Database Service (RDS)"
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
    text     = "2.2.3 Ensure that RDS instances are not publicly accessible"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_rds_db_instances_with_public_access_enabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_2_4" {
  title         = "2.2.4 Ensure Multi-AZ deployments are used for enhanced availability in Amazon RDS"
  documentation = file("./cis_v400/docs/cis_v400_2_2_4.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.2 Relational Database Service (RDS)"
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
    text     = "2.2.4 Ensure Multi-AZ deployments are used for enhanced availability in Amazon RDS"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_rds_db_instances_with_multi_az_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_2_3_1" {
  title         = "2.3.1 Ensure that encryption is enabled for EFS file systems"
  documentation = file("./cis_v400/docs/cis_v400_2_3_1.md")

  tags = {
    type   = "terminal"
    folder = "CIS v4.0.0/2 Storage/2.2 Elastic File System (EFS)"
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
    text     = "2.3.1 Ensure that encryption is enabled for EFS file systems"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.manual_detection

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

