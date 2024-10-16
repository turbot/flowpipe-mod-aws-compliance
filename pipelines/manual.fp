pipeline "manual_detection" {
  title         = "Manual Detection"
  description   = "This is a detection that requires manual verification."

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

  param "message" {
    type        = string
    description = "Message to display."
    default     = "Manual verification required."
  }

  step "message" "send_message" {
    notifier = param.notifier
    text     = param.message
  }
}
