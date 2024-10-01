pipeline "test_detect_and_correct_iam_accounts_password_policy_without_password_reuse_24_update_password_policy_reuse_prevention" {
  title       = "Test IAM accounts password policy without password reuse 24"
  description = "Test setect_and_correct_iam_accounts_password_policy_without_password_reuse_24 pipeline."

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

  step "query" "get_password_policy_without_password_reuse_24" {
    depends_on = [step.query.get_password_policy]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        (password_reuse_prevention < 24
        or password_reuse_prevention is null)
        and account_id = '${step.query.get_account_id.rows[0].account_id}'
    EOQ
  }

  step "container" "set_password_reuse_10" {
    if    = length(step.query.get_password_policy_without_password_reuse_24.rows) == 0
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = concat(
      ["iam", "update-account-password-policy"],
      ["--minimum-password-length", tostring(step.query.get_password_policy.rows[0].minimum_password_length)],
      step.query.get_password_policy.rows[0].require_symbols ? ["--require-symbols"] : ["--no-require-symbols"],
      step.query.get_password_policy.rows[0].require_numbers ? ["--require-numbers"] : ["--no-require-numbers"],
      step.query.get_password_policy.rows[0].require_lowercase_characters ? ["--require-lowercase-characters"] : ["--no-require-lowercase-characters"],
      step.query.get_password_policy.rows[0].require_uppercase_characters ? ["--require-uppercase-characters"] : ["--no-require-uppercase-characters"],
      step.query.get_password_policy.rows[0].allow_users_to_change_password ? ["--allow-users-to-change-password"] : ["--no-allow-users-to-change-password"],
      step.query.get_password_policy.rows[0].max_password_age != null ? ["--max-password-age",  tostring(step.query.get_password_policy.rows[0].max_password_age)] : [],
      ["--password-reuse-prevention",  tostring(10)]
    )

    env = credential.aws[param.cred].env
  }

  step "sleep" "sleep_100_seconds" {
    depends_on = [ step.container.set_password_reuse_10 ]
    duration   = "100s"
  }

  step "pipeline" "run_detection" {
    depends_on = [step.sleep.sleep_100_seconds]
    pipeline = pipeline.detect_and_correct_iam_accounts_password_policy_without_password_reuse_24
    args = {
      approvers       = []
      default_action  = "update_password_policy_reuse_prevention"
      enabled_actions = ["update_password_policy_reuse_prevention"]
    }
  }

  step "sleep" "sleep_30_seconds" {
    depends_on = [ step.pipeline.run_detection ]
    duration   = "30s"
  }

  step "query" "get_password_policy_after_detection" {
    depends_on = [step.sleep.sleep_30_seconds]
    database = var.database
    sql = <<-EOQ
      select
        account_id
      from
        aws_iam_account_password_policy
      where
        password_reuse_prevention = 24
        and account_id = '${step.query.get_account_id.rows[0].account_id}';
    EOQ
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_account_id"      = !is_error(step.query.get_account_id.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_account_id)}"
      "get_password_policy" = !is_error(step.query.get_password_policy.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_password_policy)}"
      "set_password_reuse_10" = !is_error(step.container.set_password_reuse_10) ? "pass" : "fail: ${error_message(step.container.set_password_reuse_10)}"
      "get_password_policy_after_detection" = length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
    }
  }
  }