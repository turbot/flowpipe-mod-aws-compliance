pipeline "test_detect_and_correct_iam_accounts_password_policy_without_one_number_update_password_policy_require_numbers" {
  title       = "Test IAM accounts password policy without one number requirement"
  description = "Test detect_and_correct_iam_accounts_password_policy_without_one_number pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  step "query" "get_account_id" {
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_account
      limit 1;
    EOQ
  }

  step "query" "get_password_policy" {
    depends_on = [step.query.get_account_id]
    database = var.database
    sql = <<-EOQ
      select
        account_id,
        minimum_password_length,
        require_symbols,
        require_numbers,
        require_uppercase_characters,
        require_lowercase_characters,
        allow_users_to_change_password,
        max_password_age,
        password_reuse_prevention
      from
        aws_iam_account_password_policy
      where
        account_id = '${step.query.get_account_id.rows[0].account_id}'
    EOQ
  }

  step "query" "get_password_policy_without_number_requirement" {
    depends_on = [step.query.get_account_id]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        (require_numbers = false
        or require_numbers is null)
        and account_id = '${step.query.get_account_id.rows[0].account_id}';
    EOQ
  }

  step "container" "set_password_policy_require_numbers" {
    if = length(step.query.get_password_policy_without_number_requirement.rows) == 0
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["iam", "update-account-password-policy"],
      ["--minimum-password-length", tostring(step.query.get_password_policy.rows[0].minimum_password_length)],
      step.query.get_password_policy.rows[0].require_symbols ? ["--require-symbols"] : ["--no-require-symbols"],
      ["--no-require-numbers"],
      step.query.get_password_policy.rows[0].require_lowercase_characters ? ["--require-lowercase-characters"] : ["--no-require-lowercase-characters"],
      step.query.get_password_policy.rows[0].require_uppercase_characters ? ["--require-uppercase-characters"] : ["--no-require-uppercase-characters"],
      step.query.get_password_policy.rows[0].allow_users_to_change_password ? ["--allow-users-to-change-password"] : ["--no-allow-users-to-change-password"],
      step.query.get_password_policy.rows[0].max_password_age != null ? ["--max-password-age",  tostring(step.query.get_password_policy.rows[0].max_password_age)] : [],
      step.query.get_password_policy.rows[0].password_reuse_prevention != null ? ["--password-reuse-prevention",  tostring(step.query.get_password_policy.rows[0].password_reuse_prevention)] : []
    )

    env = credential.aws[param.cred].env
  }

  step "pipeline" "run_detection" {
    depends_on = [step.container.set_password_policy_require_numbers]
    pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_one_number
    args = {
      approvers       = []
      default_action  = "update_password_policy_require_numbers"
      enabled_actions = ["update_password_policy_require_numbers"]
    }
  }

  step "query" "get_password_policy_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database = var.database
    sql = <<-EOQ
      select
        account_id,
        require_numbers
      from
        aws_iam_account_password_policy
      where
        require_numbers = true
        and minimum_password_length = '${step.query.get_password_policy.rows[0].minimum_password_length}'
        and max_password_age = '${step.query.get_password_policy.rows[0].max_password_age}'
        and require_symbols = '${step.query.get_password_policy.rows[0].require_symbols}'
        and require_uppercase_characters = '${step.query.get_password_policy.rows[0].require_uppercase_characters}'
        and require_lowercase_characters = '${step.query.get_password_policy.rows[0].require_lowercase_characters}'
        and allow_users_to_change_password = '${step.query.get_password_policy.rows[0].allow_users_to_change_password}'
        and password_reuse_prevention = '${step.query.get_password_policy.rows[0].password_reuse_prevention}'
        and account_id = '${step.query.get_password_policy.rows[0].account_id}';
    EOQ
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_account_id"      = !is_error(step.query.get_account_id.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_account_id)}"
      "set_password_policy_require_numbers" = !is_error(step.container.set_password_policy_require_numbers) ? "pass" : "fail: ${error_message(step.container.set_password_policy_require_numbers)}"
      "get_password_policy_after_detection" = length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
    }
  }
}
