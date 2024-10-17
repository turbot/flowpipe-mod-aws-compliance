locals {
  cis_v400_5_control_mapping = {
    cis_v400_5_1_1 = pipeline.cis_v400_5_1_1
    cis_v400_5_1_2 = pipeline.cis_v400_5_1_2
    cis_v400_5_2   = pipeline.cis_v400_5_2
    cis_v400_5_3   = pipeline.cis_v400_5_3
		cis_v400_5_4   = pipeline.cis_v400_5_4
    cis_v400_5_5   = pipeline.cis_v400_5_5
    cis_v400_5_6   = pipeline.cis_v400_5_6
		cis_v400_5_7   = pipeline.cis_v400_5_7
  }
}

variable "cis_v400_5_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v4.0.0 section 5 pipelines to enable."

  default = [
    "cis_v400_5_1_1",
    "cis_v400_5_1_2",
    "cis_v400_5_2",
    "cis_v400_5_3",
		"cis_v400_5_4",
    "cis_v400_5_5",
    "cis_v400_5_6",
		"cis_v400_5_7"
  ]

  enum = [
    "cis_v400_5_1_1",
    "cis_v400_5_1_2",
    "cis_v400_5_2",
    "cis_v400_5_3",
		"cis_v400_5_4",
    "cis_v400_5_5",
    "cis_v400_5_6",
		"cis_v400_5_7"
  ]
}

pipeline "cis_v400_5" {
  title         = "5 Networking"
  documentation = file("./cis_v400/docs/cis_v400_5.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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

  step "pipeline" "cis_v400_5" {
    depends_on = [step.message.header]
    for_each   = var.cis_v400_5_enabled_pipelines
    pipeline   = local.cis_v400_5_control_mapping[each.value]

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_5_1_1" {
  title         = "5.1.1 Ensure EBS volume encryption is enabled in all regions"
  documentation = file("./cis_v400/docs/cis_v400_5_1_1.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking/5.1 Elastic Compute Cloud (EC2)"
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
    text     = "5.1.1 Ensure EBS volume encryption is enabled in all regions"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_regions_with_ebs_encryption_by_default_disabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_5_1_2" {
  title         = "5.1.2 Ensure CIFS access is restricted to trusted networks to prevent unauthorized access"
  documentation = file("./cis_v400/docs/cis_v400_5_1_2.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking/5.1 Elastic Compute Cloud (EC2)"
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
    text     = "5.1.2 Ensure CIFS access is restricted to trusted networks to prevent unauthorized access"
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

pipeline "cis_v400_5_2" {
  title         = "5.2 Ensure no Network ACLs allow ingress from 0.0.0.0/0 to remote server administration ports"
  documentation = file("./cis_v400/docs/cis_v400_5_2.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.2 Ensure no Network ACLs allow ingress from 0.0.0.0/0 to remote server administration ports"
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

pipeline "cis_v400_5_3" {
  title         = "5.3 Ensure no security groups allow ingress from 0.0.0.0/0 to remote server administration ports"
  documentation = file("./cis_v400/docs/cis_v400_5_3.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.3 Ensure no security groups allow ingress from 0.0.0.0/0 to remote server administration ports"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_ipv4

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_5_4" {
  title         = "5.4 Ensure no security groups allow ingress from ::/0 to remote server administration ports"
  documentation = file("./cis_v400/docs/cis_v400_5_4.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.4 Ensure no security groups allow ingress from ::/0 to remote server administration ports"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_vpc_security_groups_allowing_ingress_to_remote_server_administration_ports_ipv6

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_5_5" {
  title         = "5.5 Ensure the default security group of every VPC restricts all traffic"
  documentation = file("./cis_v400/docs/cis_v400_5_5.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.5 Ensure the default security group of every VPC restricts all traffic"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_vpc_default_security_groups_allowing_ingress_egress

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}

pipeline "cis_v400_5_6" {
  title         = "5.6 Ensure routing tables for VPC peering are \"least access\""
  documentation = file("./cis_v400/docs/cis_v400_5_6.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.6 Ensure routing tables for VPC peering are \"least access\""
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

pipeline "cis_v400_5_7" {
  title         = "5.7 Ensure that the EC2 Metadata Service only allows IMDSv2"
  documentation = file("./cis_v400/docs/cis_v400_5_7.md")

  tags = {
    type   = "terminal"
		folder = "CIS v4.0.0/5 Networking"
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
    text     = "5.7 Ensure that the EC2 Metadata Service only allows IMDSv2"
  }

  step "pipeline" "run_pipeline" {
    depends_on = [step.message.header]
    pipeline   = pipeline.detect_and_correct_ec2_instances_with_imdsv1_enabled

    args = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}