pipeline "test_detect_and_correct_accounts_without_alternate_security_contact_add_alternate_contact" {
  title       = "Test detect & correct accounts without alternate security contact"
  description = "Test add the alternate security contact register action for accounts."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "title" {
    type        = string
    description = "The title of the alternate contact"
    default     = "Account alternative contact"
  }

  param "alternate_account_title" {
    type        = string
    description = "The title of the alternate contact"
    default     = "Account alternative contact"
  }

  param "name" {
    type        = string
    description = "The name of the alternate contact"
    default     = "test-fp-contact"
  }

  param "email_address" {
    type        = string
    description = "The email address of the alternate contact."
    default     = "tommy@gmail.com"
  }

  param "phone_number" {
    type        = string
    description = "The phone number of the alternate contact."
    default     = "9887263547"
  }

  step "query" "verify_register_alternative_security_contact" {
    database = var.database
    sql      = <<-EOQ
      select
        name,
        title,
        email_address,
        phone_number,
        contact_type
      from
        aws_account_alternate_contact
      where
        contact_type = 'SECURITY';
    EOQ

    throw {
      if      = length(result.rows) > 0
      message = "The alternate security contact with name '${result.rows[0].name}' is already registered. Exiting the pipeline."
    }
  }

  step "pipeline" "run_detection" {
    depends_on = [step.query.verify_register_alternative_security_contact]
    pipeline   = pipeline.correct_one_account_without_alternate_security_contact
    args = {
      title                   = param.title
      alternate_account_title = param.alternate_account_title
      email_address           = param.email_address
      phone_number            = param.phone_number
      name                    = param.name
      cred                    = param.cred
      approvers               = []
      default_action          = "add_alternate_security_contact"
      enabled_actions         = ["add_alternate_security_contact"]
    }
  }

  step "query" "registered_alternative_security_contact_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      select
        name,
        title,
        email_address,
        phone_number,
        contact_type
      from
        aws_account_alternate_contact
      where
        contact_type = 'SECURITY' and name = '${param.name}';
    EOQ
  }

 step "transform" "alternate_contact_registeration_is_matched" {
    depends_on = [step.pipeline.run_detection, step.query.registered_alternative_security_contact_after_detection]
    output "match_output" {
      value = (
        step.query.registered_alternative_security_contact_after_detection.rows[0].name == param.name &&
        step.query.registered_alternative_security_contact_after_detection.rows[0].email_address == param.email_address &&
        step.query.registered_alternative_security_contact_after_detection.rows[0].phone_number == param.phone_number &&
        step.query.registered_alternative_security_contact_after_detection.rows[0].contact_type == "SECURITY"
      )
    }
  }

  step "pipeline" "delete_register_alternative_security_contact" {
    depends_on = [step.pipeline.run_detection, step.query.registered_alternative_security_contact_after_detection, step.transform.alternate_contact_registeration_is_matched]

    pipeline = aws.pipeline.delete_alternate_contact
    args = {
      cred                   = param.cred
      alternate_contact_type = "SECURITY"
    }
  }

  output "result_add_alternate_contact" {
    description = "Test result for each step"
    value = {
      "registered_alternative_security_contact_after_detection" = length(step.query.registered_alternative_security_contact_after_detection.rows) == 1 ? "pass" : "fail"
      "matched_register_contact" = step.transform.alternate_contact_registeration_is_matched.output.match_output ? "pass" : "fail"
      "delete_register_alternative_security_contact" = !is_error(step.pipeline.delete_register_alternative_security_contact)? "pass" : "fail ${error_message(step.pipeline.delete_register_alternative_security_contact)}"
    }
  }
}
