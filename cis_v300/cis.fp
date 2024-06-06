locals {
  cis_v300_common_tags = merge(local.aws_compliance_common_tags, {
    cis         = "true"
    cis_version = "v3.0.0"
  })
}

variable "cis_v300_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 controls to enable"
  default     = ["cis_v300_1", "cis_v300_5"]
}

locals {
  cis_v300_control_mapping = {
    cis_v300_1 = { pipeline = pipeline.cis_v300_1 }
    cis_v300_5 = { pipeline = pipeline.cis_v300_5 }
  }
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

  step "message" "cis_v300" {
    notifier = notifier[param.notifier]
    text     = "Running CIS v3.0.0 Benchmark Controls: ${join(", ", var.cis_v300_enabled_controls)}"
  }
  
  step "pipeline" "cis_v300" {
    for_each = {for c in var.cis_v300_enabled_controls : c => local.cis_v300_control_mapping[c]}
    max_concurrency = 1
    pipeline = each.value.pipeline
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    } 
  }

  // step "pipeline" "cis_v300_1" {
  //   depends_on       = [step.message.cis_v300_1]
  //   pipeline         = pipeline.cis_v300_1
  //   args             = {
  //     database           = param.database
  //     notifier           = param.notifier
  //     notification_level = param.notification_level
  //     approvers          = param.approvers
  //   } 
  // }

  // step "pipeline" "cis_v300_5" {
  //   depends_on       = [step.pipeline.cis_v300_1]
  //   pipeline         = pipeline.cis_v300_5
  //   args             = {
  //     database           = param.database
  //     notifier           = param.notifier
  //     notification_level = param.notification_level
  //     approvers          = param.approvers
  //   } 
  // }

  // tags = merge(local.cis_v300_common_tags, {
  //   type = "Benchmark"
  // })
}