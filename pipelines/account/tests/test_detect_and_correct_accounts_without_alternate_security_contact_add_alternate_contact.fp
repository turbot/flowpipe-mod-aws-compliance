pipeline "test_detect_and_correct_accounts_without_alternate_security_contact_add_alternate_contact" {
  title       = "Test Detect & Correct Accounts Without Alternate Security Contact"
  description = "Test add the alternate security contact register action for accounts."

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "account_id" {
    type        = string
    description = "The AWS account ID."
    default     = "123456789012"
  }

  param "alternate_contact_type" {
    type        = string
    description = "The type of alternate contact (BILLING, OPERATIONS, SECURITY)."
    default     = "SECURITY"
  }

  param "email_address" {
    type        = string
    description = "The email address of the alternate contact."
    default     = "tommy@gmail.com"
  }

  param "name" {
    type        = string
    description = "The name of the alternate contact."
    default     = "test-fp-contact"
  }

  param "phone_number" {
    type        = string
    description = "The phone number of the alternate contact."
    default     = "9887263547"
  }

  param "title" {
    type        = string
    description = "The title of the alternate contact."
    default     = "Account alternative contact"
  }

  step "transform" "base_args" {
    output "base_args" {
      value = {
        title                  = param.title
        cred                   = param.cred
        account_id             = param.account_id
        alternate_contact_type = param.alternate_contact_type
        email_address          = param.email_address
        name                   = param.name
        phone_number           = param.phone_number
      }
    }
  }

  step "pipeline" "run_detection" {
    pipeline = pipeline.detect_and_correct_accounts_without_alternate_security_contact
    args = {
      cred                    = param.cred
      approvers               = []
      default_action          = "add_alternate_contact"
      enabled_actions         = ["add_alternate_contact"]
    }
  }

  step "query" "verify_register_alternative_security_contact" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        name,
        account_id
      from
        aws_account_alternate_contact
      where
        contact_type = 'SECURITY';
    EOQ
  }

  step "pipeline" "delete_register_alternative_security_contact" {
    depends_on = [step.query.verify_register_alternative_security_contact]

    pipeline = aws.pipeline.delete_alternate_contact
    args     = {
      alternate_contact_type = param.alternate_contact_type
    }
  }

  output "account_id" {
    description = "The ID of the account."
    value       = param.account_id
  }

  output "result_add_alternate_contact" {
    description = "Result of adding alternative security contact."
    value       = length(step.query.verify_register_alternative_security_contact.rows) == 1 ? "pass" : "fail: ${error_message(step.pipeline.run_detection)}"
  }
}
