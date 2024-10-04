// pipeline "test_detect_and_correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullaccess_detach_cloudshell_fullaccess_policy" {
//   title       = "Test detect and correct IAM entities attached with unrestricted cloudshell fullaccess policy"
//   description = "Test detect_and_correct_iam_users_groups_roles_with_unrestricted_cloudshell_fullacces pipeline."

//   tags = {
//     type = "test"
//   }

//   param "cred" {
//     type        = string
//     description = local.description_credential
//     default     = "default"
//   }

//   param "user_name" {
//     type        = string
//     description = "The name of the user."
//     default     = "flowpipe-user-${uuid()}"
//   }

//   param "role_name" {
//     type        = string
//     description = "The name of the role."
//     default     = "flowpipe-role-${uuid()}"
//   }

// 	param "group_name" {
//     type        = string
//     description = "The name of the group."
//     default     = "flowpipe-group-${uuid()}"
//   }

//   param "assume_role_policy_document" {
//     type        = string
//     description = "The assume role policy document."
//     default     =   jsonencode({
//       "Version" : "2012-10-17",
//       "Statement" : [
//         {
//           "Effect" : "Allow",
//           "Principal" : {
//             "Service" : "cloudtrail.amazonaws.com"
//           },
//           "Action" : "sts:AssumeRole"
//         }
//       ]
//     })
//   }

//   step "pipeline" "create_iam_user" {
//     pipeline   = aws.pipeline.create_iam_user
//     args = {
//       cred        = param.cred
//       user_name   = param.user_name
//     }
//   }

//   step "pipeline" "create_iam_role" {
//     depends_on = [step.pipeline.create_iam_user]
//     pipeline   = aws.pipeline.create_iam_role
//     args = {
//       cred        = param.cred
//       role_name   = param.role_name
//       assume_role_policy_document = param.assume_role_policy_document
//     }
//   }

//   step "container" "create_iam_group" {
//     depends_on = [step.pipeline.create_iam_role]
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "create-group",
//       "--group-name", param.group_name,
//     ]

//     env = credential.aws[param.cred].env
//   }

//   step "container" "attach_user_policy" {
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     depends_on = [step.container.create_iam_group]
//     cmd = [
//       "iam", "attach-user-policy",
//       "--user-name", param.user_name,
//       "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
//     ]

//     env = credential.aws[param.cred].env
//   }

//   step "container" "attach_group_policy" {
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     depends_on = [step.container.attach_user_policy]
//     cmd = [
//       "iam", "attach-group-policy",
//       "--group-name", param.group_name,
//       "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
//     ]

//     env = credential.aws[param.cred].env
//   }

//   step "container" "attach_role_policy" {
//    image = "public.ecr.aws/aws-cli/aws-cli"
//     depends_on = [step.container.attach_group_policy]
//     cmd = [
//       "iam", "attach-role-policy",
//       "--role-name", param.role_name,
//       "--policy-arn", "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
//     ]

//     env = credential.aws[param.cred].env
//   }

//   step "query" "get_entity_with_unrestricted_cloudshell_fullaccess" {
//     depends_on = [step.container.attach_group_policy]
//     database   = var.database
//     sql        = <<-EOQ
//       select
//         concat(name, '/', 'user', ' [', account_id,  ']') as title,
//         name as entity_name,
//         'user' as entity_type,
//         account_id,
//         _ctx ->> 'connection_name' as cred
//       from
//         aws_iam_user
//       where
//         attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//         and name = '${param.user_name}'

//     union

//     select
//       concat(name, '/', 'role', ' [', account_id,  ']') as title,
//       name as entity_name,
//       'role' as entity_type,
//       account_id,
//       _ctx ->> 'connection_name' as cred
//     from
//       aws_iam_role
// 		where
// 			attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//       and name = '${param.role_name}'

//     union

//     select
//       concat(name, '/', 'group', ' [', account_id,  ']') as title,
//       name as entity_name,
//       'group' as entity_type,
//       account_id,
//       _ctx ->> 'connection_name' as cred
//     from
//       aws_iam_group
// 		where
// 			attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//       and name = '${param.group_name}'
//     EOQ
//   }

//   step "pipeline" "run_detection" {
//     depends_on = [step.query.get_entity_with_unrestricted_cloudshell_fullaccess]
//     for_each        = { for item in step.query.get_entity_with_unrestricted_cloudshell_fullaccess.rows : item.title => item }
//     max_concurrency = var.max_concurrency
//     pipeline        = pipeline.correct_iam_user_group_role_with_unrestricted_cloudshell_fullaccess
//     args = {
//       title                  = each.value.title
//       entity_name            = each.value.entity_name
//       entity_type            = each.value.entity_type
//       account_id             = each.value.account_id
//       cred                   = each.value.cred
//       approvers              = []
//       default_action         = "detach_cloudshell_fullaccess_policy"
//       enabled_actions        = ["detach_cloudshell_fullaccess_policy"]
//     }
//   }

//   step "sleep" "sleep_70_seconds" {
//     depends_on = [ step.pipeline.run_detection ]
//     duration   = "70s"
//   }

//   step "query" "get_details_after_detection" {
//     depends_on = [step.sleep.sleep_70_seconds]
//     database = var.database
//     sql = <<-EOQ
//       select
//       concat(name, ' [', account_id, ']') as title,
//       name as entity_name,
//       'user' as entity_type,
//       account_id,
//       _ctx ->> 'connection_name' as cred
//     from
//       aws_iam_user
//     where
//       attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//       and name = '${param.user_name}'

//     union

//     select
//       concat(name, ' [', account_id, ']') as title,
//       name as entity_name,
//       'role' as entity_type,
//       account_id,
//       _ctx ->> 'connection_name' as cred
//     from
//       aws_iam_role
// 		where
// 			attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//       and name = '${param.role_name}'

//     union

//     select
//       concat(name, ' [', account_id, ']') as title,
//       name as entity_name,
//       'group' as entity_type,
//       account_id,
//       _ctx ->> 'connection_name' as cred
//     from
//       aws_iam_group
// 		where
// 			attached_policy_arns @> '["arn:aws:iam::aws:policy/AWSCloudShellFullAccess"]'
//       and name = '${param.group_name}'
//     EOQ
//   }

//   step "pipeline" "delete_iam_user" {
//     depends_on = [step.query.get_details_after_detection]
//     pipeline   = aws.pipeline.delete_iam_user
//     args = {
//       cred        = param.cred
//       user_name   = param.user_name
//     }
//   }

//   step "pipeline" "delete_iam_role" {
//     depends_on = [step.pipeline.delete_iam_user]
//     pipeline   = aws.pipeline.delete_iam_role
//     args = {
//       cred        = param.cred
//       role_name   = param.role_name
//     }
//   }

//   step "container" "delete_iam_group" {
//     depends_on = [step.pipeline.delete_iam_role]
//     image = "public.ecr.aws/aws-cli/aws-cli"
//     cmd = [
//       "iam", "delete-group",
//       "--group-name", param.group_name
//     ]

//     env = credential.aws[param.cred].env
//   }

//   output "test_results" {
//     description = "Test results for each step."
//     value = {
//       "create_iam_user"                               = !is_error(step.pipeline.create_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_user)}"
//       "create_iam_role"                               = !is_error(step.pipeline.create_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.create_iam_role)}"
//       "create_iam_group"                              = !is_error(step.container.create_iam_group) ? "pass" : "fail: ${error_message(step.container.create_iam_group)}"
//       "attach_user_policy"                            = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_user_policy)}"
//       "attach_role_policy"                            = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_role_policy)}"
//       "attach_group_policy"                           = !is_error(step.container.attach_user_policy) ? "pass" : "fail: ${error_message(step.container.attach_group_policy)}"
//       "get_entity_with_unrestricted_cloudshell_fullaccess" = length(step.query.get_entity_with_unrestricted_cloudshell_fullaccess.rows) == 3 ? "pass" : "fail: Row length is not 3"
//       "get_details_after_detection"                   = length(step.query.get_details_after_detection.rows) == 0 ? "pass" : "fail: Row length is not 0"
//       "delete_iam_user"                               = !is_error(step.pipeline.delete_iam_user) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_user)}"
//       "delete_iam_role"                               = !is_error(step.pipeline.delete_iam_role) ? "pass" : "fail: ${error_message(step.pipeline.delete_iam_role)}"
//       "delete_iam_group"                              = !is_error(step.container.delete_iam_group) ? "pass" : "fail: ${error_message(step.container.delete_iam_group)}"
//     }
//   }
// }
