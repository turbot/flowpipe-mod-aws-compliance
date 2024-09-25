locals {
  cis_v300_control_mapping = {
    cis_v300_1 = pipeline.cis_v300_1
    cis_v300_2 = pipeline.cis_v300_2
    cis_v300_3 = pipeline.cis_v300_3
    cis_v300_4 = pipeline.cis_v300_4
    cis_v300_5 = pipeline.cis_v300_5
  }
}

variable "cis_v300_enabled_pipelines" {
  type        = list(string)
  description = "List of CIS v3.0.0 pipelines to enable."

  default = [
    "cis_v300_1",
    "cis_v300_2",
    /*
    "cis_v300_3",
    "cis_v300_4",
    "cis_v300_5"
    */
  ]
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

  step "message" "header" {
    #if       = (step.transform.input_value.value == "yes")
    notifier = notifier[param.notifier]
    text     = "CIS v3.0.0"
  }

  step "pipeline" "run_pipelines" {
    loop {
      until = loop.index >= (length(var.cis_v300_enabled_pipelines)-1)
    }

    pipeline = local.cis_v300_control_mapping[var.cis_v300_enabled_pipelines[loop.index]]
    args     = {
      database           = param.database
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
    }
  }
}
