locals {
  cis_v300_common_tags = merge(local.aws_compliance_common_tags, {
    cis         = "true"
    cis_version = "v3.0.0"
  })
}

pipeline "cis_v300" {
  title         = "CIS v3.0.0"
  description   = "The CIS Amazon Web Services Foundations Benchmark provides prescriptive guidance for configuring security options for a subset of Amazon Web Services with an emphasis on foundational, testable, and architecture agnostic settings."
  documentation = file("./cis_v300/docs/cis_overview.md")

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

  step "pipeline" "cis_v300_1" {
    pipeline         = pipeline.detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports
    args             = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    } 
  }

  step "pipeline" "cis_v300_5" {
    pipeline         = pipeline.detect_and_correct_vpc_networks_allowing_ingress_to_remote_server_administration_ports
    args             = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    } 
  }

  // tags = merge(local.cis_v300_common_tags, {
  //   type = "Benchmark"
  // })
}