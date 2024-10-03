pipeline "test_detect_and_correct_iam_accounts_password_policy_without_one_symbol_update_password_policy_require_symbols" {
  title       = "Test detect and correct IAM account password policies without one symbol requirement"
  description = "Test detect_and_correct_iam_accounts_password_policy_without_one_symbol pipeline."

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
        password_reuse_prevention,
        coalesce(max_password_age, 0) as effective_max_password_age,
        coalesce(password_reuse_prevention, 0) as effective_password_reuse_prevention
      from
        aws_iam_account_password_policy
      where
        account_id = '${step.query.get_account_id.rows[0].account_id}'
    EOQ
  }

  step "query" "get_password_policy_without_symbol_requirement" {
    depends_on = [step.query.get_account_id]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        (require_symbols = false
      	or require_symbols is null)
        and account_id = '${step.query.get_account_id.rows[0].account_id}';
    EOQ
  }

  step "pipeline" "disable_password_policy_require_symbol" {
    if        = length(step.query.get_password_policy_without_symbol_requirement.rows) == 0
    pipeline  = aws.pipeline.update_iam_account_password_policy
    args = {
      allow_users_to_change_password = step.query.get_password_policy.rows[0].allow_users_to_change_password
      cred                           = param.cred
      max_password_age               = step.query.get_password_policy.rows[0].effective_max_password_age
      minimum_password_length        = step.query.get_password_policy.rows[0].minimum_password_length
      password_reuse_prevention      = step.query.get_password_policy.rows[0].effective_password_reuse_prevention
      require_lowercase_characters   = step.query.get_password_policy.rows[0].require_lowercase_characters
      require_numbers                = step.query.get_password_policy.rows[0].require_numbers
      require_symbols                = false
      require_uppercase_characters   = step.query.get_password_policy.rows[0].require_uppercase_characters
    }
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.disable_password_policy_require_symbol]
    pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_one_symbol
    args = {
      approvers       = []
      default_action  = "update_password_policy_require_symbols"
      enabled_actions = ["update_password_policy_require_symbols"]
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
        require_symbols = true
        and require_numbers = '${step.query.get_password_policy.rows[0].require_numbers}'
        and minimum_password_length = '${step.query.get_password_policy.rows[0].minimum_password_length}'
        and max_password_age = '${step.query.get_password_policy.rows[0].max_password_age}'
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
      "get_account_id"                         = !is_error(step.query.get_account_id.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_account_id)}"
      "get_password_policy"                    = !is_error(step.query.get_password_policy.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_password_policy)}"
      "disable_password_policy_require_symbol" = !is_error(step.pipeline.disable_password_policy_require_symbol) ? "pass" : "fail: ${error_message(step.pipeline.disable_password_policy_require_symbol)}"
      "get_password_policy_after_detection"    = length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
    }
  }
}
