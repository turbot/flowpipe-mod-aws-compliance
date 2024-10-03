// Need to cross check the step 'registered_alternative_security_contact' why it is not reslting back the details even thoung the resource is created
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

  step "transform" "base_args" {
    output "base_args" {
      value = {
        title                  = "Account alternative contact"
        alternate_contact_type = "SECURITY"
        email_address          = "tommy@gmail.com"
        name                   = "test-fp-contact"
        phone_number           = "9887263547"
      }
    }
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
      alternate_account_title = step.transform.base_args.output.base_args.title
      title                   = step.transform.base_args.output.base_args.title
      email_address           = step.transform.base_args.output.base_args.email_address
      phone_number            = step.transform.base_args.output.base_args.phone_number
      name                    = step.transform.base_args.output.base_args.name
      cred                    = param.cred
      approvers               = []
      default_action          = "add_alternate_security_contact"
      enabled_actions         = ["add_alternate_security_contact"]
    }
  }

  step "query" "registered_alternative_security_contact" {
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
        contact_type = 'SECURITY';
    EOQ
  }

  step "transform" "alternate_contact_registeration_is_matched" {
    depends_on = [step.pipeline.run_detection, step.query.registered_alternative_security_contact]
    output "match_output" {
      value = (
        step.transform.base_args.output.base_args.name == step.query.registered_alternative_security_contact.rows[0].name &&
        step.transform.base_args.output.base_args.email_address == step.query.registered_alternative_security_contact.rows[0].email_address &&
        step.transform.base_args.output.base_args.phone_number == step.query.registered_alternative_security_contact.rows[0].phone_number &&
        step.transform.base_args.output.base_args.alternate_contact_type == step.query.registered_alternative_security_contact.rows[0].contact_type
      )
    }
  }

  step "pipeline" "delete_register_alternative_security_contact" {
    depends_on = [step.pipeline.run_detection, step.query.registered_alternative_security_contact]

    pipeline = aws.pipeline.delete_alternate_contact
    args = {
      cred                   = param.cred
      alternate_contact_type = "SECURITY"
    }
  }

  output "result_add_alternate_contact" {
    description = "Test result for each step"
    value = {
      "registered_alternative_security_contact" = length(step.query.registered_alternative_security_contact.rows) == 1 ? "pass" : "fail"
      "matched_register_contact" : step.transform.alternate_contact_registeration_is_matched.output.match_output ? "pass" : "fail"
    }
  }
}
