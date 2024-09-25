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
    default     = "Please check for detections manually."
  }

  step "message" "manual_control" {
    notifier = notifier[param.notifier]
    text     = param.message
  }
}
