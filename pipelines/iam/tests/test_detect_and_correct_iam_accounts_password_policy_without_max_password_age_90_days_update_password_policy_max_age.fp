pipeline "test_detect_and_correct_iam_accounts_password_policy_without_max_password_age_90_days_update_password_policy_max_age" {
  title       = "Test IAM accounts password policy without max password age of 90 days"
  description = "Test detect_and_correct_iam_accounts_password_policy_without_max_password_age_90_days pipeline."

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

  step "query" "get_password_policy_with_password_max_age_less_than_90_days" {
    depends_on = [step.query.get_password_policy]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        (max_password_age < 90
        or max_password_age is null)
        and account_id = '${step.query.get_account_id.rows[0].account_id}';
    EOQ
  }

  step "container" "set_password_max_age_60_days" {
    if    = length(step.query.get_password_policy_with_password_max_age_less_than_90_days.rows) == 0
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["iam", "update-account-password-policy"],
      ["--minimum-password-length", tostring(step.query.get_password_policy.rows[0].minimum_password_length)],
      step.query.get_password_policy.rows[0].require_symbols ? ["--require-symbols"] : ["--no-require-symbols"],
      step.query.get_password_policy.rows[0].require_numbers ? ["--require-numbers"] : ["--no-require-numbers"],
      step.query.get_password_policy.rows[0].require_lowercase_characters ? ["--require-lowercase-characters"] : ["--no-require-lowercase-characters"],
      step.query.get_password_policy.rows[0].require_uppercase_characters ? ["--require-uppercase-characters"] : ["--no-require-uppercase-characters"],
      step.query.get_password_policy.rows[0].allow_users_to_change_password ? ["--allow-users-to-change-password"] : ["--no-allow-users-to-change-password"],
      ["--max-password-age",  tostring(60)],
      step.query.get_password_policy.rows[0].password_reuse_prevention != null ? ["--password-reuse-prevention",  tostring(step.query.get_password_policy.rows[0].password_reuse_prevention)] : []
    )
    env = credential.aws[param.cred].env
	}

  step "pipeline" "run_detection" {
    depends_on = [step.container.set_password_max_age_60_days]
    pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_max_password_age_90_days
    args = {
      approvers       = []
      default_action  = "update_password_policy_max_age"
      enabled_actions = ["update_password_policy_max_age"]
    }
  }

  step "query" "get_password_policy_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        max_password_age = 90
        and minimum_password_length = '${step.query.get_password_policy.rows[0].minimum_password_length}'
        and require_symbols = '${step.query.get_password_policy.rows[0].require_symbols}'
        and require_numbers = '${step.query.get_password_policy.rows[0].require_numbers}'
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
      "get_password_policy" = !is_error(step.query.get_password_policy.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_password_policy)}"
      "set_password_max_age_60_days" = !is_error(step.container.set_password_max_age_60_days) ? "pass" : "fail: ${error_message(step.container.set_password_max_age_60_days)}"
      "get_password_policy_after_detection" = length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
    }
  }
}
