// // Variables to create the VPC Flow Log
// variable "vpc_flow_log_role_policy" {
//   type        = string
//   description = "The default IAM role policy to apply"
//   default     = <<-EOF
// {
//   "Version": "2012-10-17",
//   "Statement": [
//     {
//       "Sid": "test",
//       "Effect": "Allow",
//       "Principal": {
//         "Service": "ec2.amazonaws.com"
//       },
//       "Action": "sts:AssumeRole"
//     }
//   ]
// }
//   EOF
// }

// variable "vpc_flow_log_iam_policy" {
//   type        = string
//   description = "The default IAM policy to apply"
//   default     = <<-EOF
// {
//   "Version": "2012-10-17",
//   "Statement": [
//     {
//       "Effect": "Allow",
//       "Action": [
//         "logs:CreateLogGroup",
//         "logs:CreateLogStream",
//         "logs:DescribeLogGroups",
//         "logs:DescribeLogStreams",
//         "logs:PutLogEvents",
//         "logs:GetLogEvents",
//         "logs:FilterLogEvents"
//       ],
//       "Resource": "*"
//     }
//   ]
// }
//   EOF
// }

// variable "aws_vpc_flow_log_role_name" {
//   type        = string
//   description = "IAM role for AWS VPC Flow Log"
//   default     = "FlowpipeRemediateEnableVPCFlowLogIAMRole"
// }

// variable "aws_vpc_flow_log_iam_policy_name" {
//   type        = string
//   description = "IAM policy for AWS VPC Flow Log"
//   default     = "FlowpipeRemediateEnableVPCFlowLogIAMPolicy"
// }

// pipeline "create_iam_role_and_policy" {
//   title = "Create IAM role and policy"
//   description = "Create IAM role and policy."

//   param "region" {
//     type        = string
//     description = local.description_region
//   }

//   param "cred" {
//     type        = string
//     description = local.description_credential
//   }

//   step "pipeline" "create_iam_role" {
//     pipeline = aws.pipeline.create_iam_role  
//     args = {
//       role_name = var.aws_vpc_flow_log_role_name
//       assume_role_policy_document = var.vpc_flow_log_role_policy
//     }
//   }

//   step "pipeline" "create_iam_policy" {
//     pipeline = aws.pipeline.create_iam_policy  
//     args = {
//       policy_name = var.aws_vpc_flow_log_iam_policy_name
//       policy_document = var.vpc_flow_log_iam_policy
//     }
//   }

//   step "pipeline" "attach_iam_role_policy" {
//     pipeline = aws.pipeline.attach_iam_role_policy  
//     args = {
//       role_name = var.aws_vpc_flow_log_role_name
//       policy_arn = step.pipeline.output.create_iam_policy.Policy.Arn
//     }
//   }

// }

// pipeline "create_vpc_flowlog" {
//   title = "Create VPC Flow Log"
//   description = "Create VPC flow log."

//   param
// }