pipeline "test_detect_and_correct_iam_account_password_policies_without_min_length_14_update_password_policy_min_length" {
  title       = "Test detect and correct IAM account password policies without minimum length of 14"
  description = "Test detect_and_correct_iam_account_password_policies_without_min_length_14 pipeline ."

  tags = {
    type = "test"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
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
    database   = var.database
    sql = <<-EOQ
      select
        a.account_id as title,
        pol.account_id as password_policy_account_id,
        minimum_password_length,
        require_symbols,
        require_numbers,
        require_uppercase_characters,
        require_lowercase_characters,
        allow_users_to_change_password,
        max_password_age,
        password_reuse_prevention,
        coalesce(max_password_age, 0) as effective_max_password_age,
        coalesce(password_reuse_prevention, 0) as effective_password_reuse_prevention,
        a.sp_connection_name as conn
      from
        aws_account as a
        left join aws_iam_account_password_policy as pol on a.account_id = pol.account_id
      where
        a.account_id = '${step.query.get_account_id.rows[0].account_id}';
    EOQ
  }

  step "query" "get_password_policy_with_minimum_password_length_less_than_14" {
    depends_on = [step.query.get_password_policy]
    database   = var.database
    sql = <<-EOQ
      select
        pol.account_id as password_policy_account_id
      from
        aws_account as a
        left join aws_iam_account_password_policy as pol on a.account_id = pol.account_id
      where
        minimum_password_length < 14
        and a.account_id = '${step.query.get_account_id.rows[0].account_id}'
    EOQ
  }

  step "pipeline" "set_password_policy_length_7" {
    depends_on = [step.query.get_password_policy_with_minimum_password_length_less_than_14]
     if        = length(step.query.get_password_policy_with_minimum_password_length_less_than_14.rows) == 0 && (step.query.get_password_policy.rows[0].password_policy_account_id) != null
    pipeline   = aws.pipeline.update_iam_account_password_policy
    args = {
      allow_users_to_change_password = step.query.get_password_policy.rows[0].allow_users_to_change_password
      conn                           = param.conn
      max_password_age               = step.query.get_password_policy.rows[0].effective_max_password_age
      minimum_password_length        = 7
      password_reuse_prevention      = step.query.get_password_policy.rows[0].effective_password_reuse_prevention
      require_lowercase_characters   = step.query.get_password_policy.rows[0].require_lowercase_characters
      require_numbers                = step.query.get_password_policy.rows[0].require_numbers
      require_symbols                = step.query.get_password_policy.rows[0].require_symbols
      require_uppercase_characters   = step.query.get_password_policy.rows[0].require_uppercase_characters
    }
  }

  step "pipeline" "run_detection" {
    depends_on      = [step.pipeline.set_password_policy_length_7]
    for_each        = { for item in step.query.get_password_policy.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_iam_account_password_policy_without_min_length_14
    args = {
      title                  = each.value.title
      account_id             = each.value.title
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "update_password_policy_min_length"
      enabled_actions        = ["update_password_policy_min_length"]
    }
  }

  step "query" "get_password_policy_after_detection" {
    if         = (step.query.get_password_policy.rows[0].password_policy_account_id) != null
    depends_on = [step.pipeline.run_detection]
    database = var.database
    sql = <<-EOQ
      select
        account_id,
        minimum_password_length
      from
        aws_iam_account_password_policy
      where
        minimum_password_length = 14
        and require_symbols = '${step.query.get_password_policy.rows[0].require_symbols}'
        and require_numbers = '${step.query.get_password_policy.rows[0].require_numbers}'
        and require_uppercase_characters = '${step.query.get_password_policy.rows[0].require_uppercase_characters}'
        and require_lowercase_characters = '${step.query.get_password_policy.rows[0].require_lowercase_characters}'
        and allow_users_to_change_password = '${step.query.get_password_policy.rows[0].allow_users_to_change_password}'
        and (
          -- Conditional check for null in password_reuse_prevention
          ${step.query.get_password_policy.rows[0].password_reuse_prevention == null ? "password_reuse_prevention IS NULL" : "password_reuse_prevention = '" + step.query.get_password_policy.rows[0].password_reuse_prevention + "'"}
        )
        and (
          -- Conditional check for null in max_password_age
          ${step.query.get_password_policy.rows[0].max_password_age == null ? "max_password_age IS NULL" : "max_password_age = '" + step.query.get_password_policy.rows[0].max_password_age + "'"}
        )
        and account_id = '${step.query.get_password_policy.rows[0].title}';
    EOQ
  }

  step "pipeline" "set_password_policy_length_to_old_setting" {
    if         = (step.query.get_password_policy.rows[0].password_policy_account_id) != null
    depends_on = [step.query.get_password_policy_after_detection]
    pipeline   = aws.pipeline.update_iam_account_password_policy
    args = {
      allow_users_to_change_password = step.query.get_password_policy.rows[0].allow_users_to_change_password
      conn                           = param.conn
      max_password_age               = step.query.get_password_policy.rows[0].effective_max_password_age
      minimum_password_length        = step.query.get_password_policy.rows[0].minimum_password_length
      password_reuse_prevention      = step.query.get_password_policy.rows[0].effective_password_reuse_prevention
      require_lowercase_characters   = step.query.get_password_policy.rows[0].require_lowercase_characters
      require_numbers                = step.query.get_password_policy.rows[0].require_numbers
      require_symbols                = step.query.get_password_policy.rows[0].require_symbols
      require_uppercase_characters   = step.query.get_password_policy.rows[0].require_uppercase_characters
    }
  }

  step "container" "delete_iam_account_password_policy" {
    if     =(step.query.get_password_policy.rows[0].password_policy_account_id) == null
    depends_on = [step.pipeline.set_password_policy_length_to_old_setting]
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "iam", "delete-account-password-policy"
    ]

    env = connection.aws[param.conn].env
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "get_account_id"                      = !is_error(step.query.get_account_id.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_account_id)}"
      "get_password_policy"                 = (step.query.get_password_policy.rows[0].password_policy_account_id) != null ? !is_error(step.query.get_password_policy.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_password_policy)}" : "No password policy set (Default settings)"
      "set_password_policy_length_7"        = (step.query.get_password_policy.rows[0].password_policy_account_id) != null ? !is_error(step.pipeline.set_password_policy_length_7) ? "pass" : "fail: ${error_message(step.pipeline.set_password_policy_length_7)}" : "Not required to set policy length to 7"
      "get_password_policy_after_detection" = (step.query.get_password_policy.rows[0].password_policy_account_id) != null ? length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1" : "Restored to default settings"
    }
  }
}
