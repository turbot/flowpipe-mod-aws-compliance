locals {
  cis_v300_common_tags = merge(local.aws_compliance_common_tags, {
    cis         = "true"
    cis_version = "v3.0.0"
  })
  cis_v300_control_mapping = {
    cis_v300_1 = { pipeline = pipeline.cis_v300_1 }
    cis_v300_5 = { pipeline = pipeline.cis_v300_5 }
  }
}

variable "cis_v300_enabled_controls" {
  type        = list(string)
  description = "List of CIS v3.0.0 controls to enable"
  default     = ["cis_v300_1", "cis_v300_5"]
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

  // TODO: Check this out later
  // step "pipeline" "should_run" {
  //   if = length(param.approvers) > 0 

  //   pipeline = detect_correct.pipeline.decision
  //   args = {
  //     notifier = param.approvers[0]
  //     prompt   = "Do you wish to run CIS v3.0.0 Section 1: Identity and Access Management?"
  //     options  = [
  //       {value = "no", label = "No", style = local.style_alert},
  //       {value = "yes", label = "Yes", style = local.style_ok}
  //     ]
  //   }
  // }

    step "pipeline" "cis_v300" {
    loop {
      until = loop.index >= (length(var.cis_v300_enabled_controls)-1)
    }

    pipeline = local.cis_v300_control_mapping[var.cis_v300_enabled_controls[loop.index]].pipeline
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    } 
  }
}

// TODO: Move this somewhere else
pipeline "manual_control" {
  title         = "Manual Control"
  description   = "This is a manual control that requires human intervention."
  documentation =  "" // TODO: Add documentation

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

  param "message" {
    type        = string
    description = "Message to display."
  }

  step "message" "manual_control" {
    notifier = notifier[param.notifier]
    text     = param.message
  }
}