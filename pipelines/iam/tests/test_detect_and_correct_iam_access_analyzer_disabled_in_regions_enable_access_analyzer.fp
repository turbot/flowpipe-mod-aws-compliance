// pipeline "test_detect_and_correct_iam_access_analyzer_disabled_in_regions_enable_access_analyzer" {
//   title       = "Test IAM Access Analyzer disabled in regions"
//   description = "Test detect_and_correct_iam_access_analyzer_disabled_in_region pipeline."

//   tags = {
//     type = "test"
//   }

//   param "cred" {
//     type        = string
//     description = local.description_credential
//     default     = "default"
//   }

//  	step "query" "get_access_analyzer_disabled_region" {
// 		database = var.database
//     sql = <<-EOQ
//       select
// 				r.account_id,
// 				r.region,
// 				r._ctx ->> 'connection_name' as cred
// 			from
// 				aws_region as r
// 				left join aws_accessanalyzer_analyzer as aa on r.account_id = aa.account_id and r.region = aa.region
// 			where
// 				r.opt_in_status <> 'not-opted-in'
// 				and aa.arn is null limit 1;
//     EOQ
//   }

//   step "container" "get_one_access_analyzer_enabled_region" {
// 		if    = length(step.query.get_password_policy_with_password_max_age_less_than_90_days.rows) == 0
//     image = "public.ecr.aws/aws-cli/aws-cli"

//    	cmd = concat(
//       ["iam", "update-account-password-policy"],
//       ["--minimum-password-length", tostring(step.query.get_password_policy.rows[0].minimum_password_length)],
// 			step.query.get_password_policy.rows[0].require_symbols ? ["--require-symbols"] : ["--no-require-symbols"],
// 			step.query.get_password_policy.rows[0].require_numbers ? ["--require-numbers"] : ["--no-require-numbers"],
//       step.query.get_password_policy.rows[0].require_lowercase_characters ? ["--require-lowercase-characters"] : ["--no-require-lowercase-characters"],
//       step.query.get_password_policy.rows[0].require_uppercase_characters ? ["--require-uppercase-characters"] : ["--no-require-uppercase-characters"],
// 			step.query.get_password_policy.rows[0].allow_users_to_change_password ? ["--allow-users-to-change-password"] : ["--no-allow-users-to-change-password"],
// 			["--max-password-age",  tostring(60)],
// 			step.query.get_password_policy.rows[0].password_reuse_prevention != null ? ["--password-reuse-prevention",  tostring(step.query.get_password_policy.rows[0].password_reuse_prevention)] : []
//     )
//     env = credential.aws[param.cred].env
// 	}

// 	step "sleep" "sleep_100_seconds" {
// 		depends_on = [ step.container.set_password_max_age_60_days ]
// 		duration   = "100s"
// 	}

//   step "pipeline" "run_detection" {
//     depends_on = [step.sleep.sleep_100_seconds]
//     pipeline = pipeline.detect_and_correct_iam_access_analyzer_disabled_in_regions
//     args = {
//       approvers       = []
//       default_action  = "update_password_policy_max_age"
//       enabled_actions = ["update_password_policy_max_age"]
//     }
//   }

// 	step "sleep" "sleep_30_seconds" {
// 		depends_on = [ step.pipeline.run_detection ]
// 		duration   = "30s"
// 	}

//   step "query" "get_password_policy_after_detection" {
//     depends_on = [step.sleep.sleep_30_seconds]
//     database = var.database
//     sql = <<-EOQ
//       select
// 				account_id
//       from
//         aws_iam_account_password_policy
// 			where
// 				max_password_age = 90
//       	and account_id = '${step.query.get_account_id.rows[0].account_id}';
//     EOQ
//   }

//   output "test_results" {
//     description = "Test results for each step."
//     value = {
// 			"get_account_id"      = !is_error(step.query.get_account_id.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_account_id)}"
// 			"get_password_policy" = !is_error(step.query.get_password_policy.rows[0]) ? "pass" : "fail: ${error_message(step.query.get_password_policy)}"
//       "set_password_max_age_60_days" = !is_error(step.container.set_password_max_age_60_days) ? "pass" : "fail: ${error_message(step.container.set_password_max_age_60_days)}"
// 			"get_password_policy_after_detection" = length(step.query.get_password_policy_after_detection.rows) == 1 ? "pass" : "fail: Row length is not 1"
//     }
//   }
// }
