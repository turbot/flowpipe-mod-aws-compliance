// Tags
locals {
  aws_compliance_common_tags = {
    category = "Compliance"
    mod      = "aws"
    service  = "AWS"
  }
}

// Consts
locals {
  level_error   = "error"
  level_info    = "info"
  level_verbose = "verbose"
  style_alert   = "alert"
  style_info    = "info"
  style_ok      = "ok"
}

// Common Texts
locals {
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_database         = "Database connection string."
  description_default_action   = "The default action to use when there are no approvers."
  description_enabled_actions  = "The list of enabled actions approvers can select."
  description_items            = "A collection of detected resources to run corrective actions against."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_region           = "AWS Region of the resource(s)."
  description_resource         = "The name of the resource"
  description_title            = "Title of the resource, to be used as a display name."
}

