pipeline "test_cloudtrail_trail_logs_not_encrypted_with_kms_cmk" {
  title       = "Test CloudTrail trail logs not encrypted with KMS CMK"
  description = "Tests the CloudTrail Trail Logs Not Encrypted with KMS CMK."

  param "conn" {
    type        = connection.aws
    description = "The AWS connection to use."
    default     = connection.aws.default
  }

  param "region" {
    type        = string
    description = "The AWS region."
    default     = "us-east-1"
  }

  param "trail_name" {
    type        = string
    description = "The name of the CloudTrail trail."
    default     = "test-cloudtrail-${uuid()}"
  }

  param "s3_bucket" {
    type        = string
    description = "The S3 bucket for CloudTrail logs."
    default     = "test-cloudtrail-s3-bucket-${uuid()}"
  }

  tags = {
    type = "test"
  }

  # Step to create the S3 bucket for CloudTrail logs
  step "pipeline" "create_s3_bucket" {
    pipeline = aws.pipeline.create_s3_bucket
    args = {
      bucket = param.s3_bucket
      conn   = param.conn
      region = param.region
    }
  }

  # Step to get AWS Account ID
  step "query" "get_account_id" {
    database = var.database
    sql      = <<-EOQ
      select
        account_id
      from
        aws_account
      limit 1;
    EOQ
  }

  # Step to set the S3 bucket policy for CloudTrail
  step "transform" "generate_s3_bucket_policy" {
    depends_on = [step.query.get_account_id]
    output "policy" {
      value = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "AWSCloudTrailAclCheck20150319",
            "Effect" : "Allow",
            "Principal" : {
              "Service" : "cloudtrail.amazonaws.com"
            },
            "Action" : "s3:GetBucketAcl",
            "Resource" : "arn:aws:s3:::${param.s3_bucket}"
          },
          {
            "Sid" : "AWSCloudTrailWrite20150319",
            "Effect" : "Allow",
            "Principal" : {
              "Service" : "cloudtrail.amazonaws.com"
            },
            "Action" : "s3:PutObject",
            "Resource" : "arn:aws:s3:::${param.s3_bucket}/AWSLogs/${step.query.get_account_id.rows[0].account_id}/*",
            "Condition" : {
              "StringEquals" : {
                "s3:x-amz-acl" : "bucket-owner-full-control"
              }
            }
          }
        ]
      })
    }
  }

  # Apply the S3 bucket policy
  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.transform.generate_s3_bucket_policy]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      bucket = param.s3_bucket
      policy = step.transform.generate_s3_bucket_policy.output.policy
      conn   = param.conn
      region = param.region
    }
  }

  # Step to create a CloudTrail trail without encryption
  step "pipeline" "create_cloudtrail_trail" {
    depends_on = [step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      name                          = param.trail_name
      region                        = param.region
      conn                          = param.conn
      bucket_name                   = param.s3_bucket
      is_multi_region_trail         = false
      include_global_service_events = true
      enable_log_file_validation    = false
    }
  }

  # Step to create a KMS key for CloudTrail trail logs
  step "container" "create_kms_key" {
    depends_on = [step.pipeline.create_cloudtrail_trail]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "kms", "create-key",
      "--key-usage", "ENCRYPT_DECRYPT",
      "--description", "Key for CloudTrail trail logs",
      "--region", param.region,
      "--output", "json"
    ]
    env = connection.aws[param.conn].env
  }

  # Step to check if the CloudTrail trail log is unencrypted
  step "query" "cloudtrail_logs_unencrypted" {
    depends_on = [step.container.create_kms_key]
    database   = var.database
    sql        = <<-EOQ
      select
        concat(name, ' [', account_id, '/', region, ']') as title,
        region,
        sp_connection_name as conn,
        account_id,
        name
      from
        aws_cloudtrail_trail
      where
        name = '${param.trail_name}'
        and kms_key_id is null;
    EOQ
  }

  # Update the CloudTrail trail to use the KMS key
  step "pipeline" "run_corrective_action" {
    if       = length(step.query.cloudtrail_logs_unencrypted.rows) == 1
    pipeline = pipeline.correct_one_cloudtrail_trail_log_not_encrypted_with_kms_cmk
    args = {
      title               = step.query.cloudtrail_logs_unencrypted.rows[0].title
      kms_key_id          = jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId
      kms_key_policy_name = "default"
      account_id          = step.query.get_account_id.rows[0].account_id
      region              = param.region
      name                = param.trail_name
      conn                = step.query.cloudtrail_logs_unencrypted.rows[0].conn
      approvers           = []
      default_action      = "encrypt_cloud_trail_logs"
      enabled_actions     = ["encrypt_cloud_trail_logs"]
    }
  }

  # Verify that the CloudTrail trail is now encrypted with the CMK
  step "query" "verify_encryption" {
    depends_on = [step.pipeline.run_corrective_action]
    database   = var.database
    sql        = <<-EOQ
      select
        name,
        kms_key_id
      from
        aws_cloudtrail_trail
      where
        name = '${param.trail_name}'
        and kms_key_id = 'arn:aws:kms:${param.region}:${step.query.get_account_id.rows[0].account_id}:key/${jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId}';
    EOQ
  }

  output "result" {
    description = "Result of the encryption test."
    value       = length(step.query.verify_encryption.rows) == 1 ? "CloudTrail trail is now encrypted with KMS CMK." : "CloudTrail trail encryption failed."
  }

  # Step to empty the S3 bucket before deletion
  step "container" "empty_s3_bucket" {
    depends_on = [step.query.verify_encryption]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3", "rm", "s3://${param.s3_bucket}", "--recursive",
      "--region", param.region
    ]
    env = connection.aws[param.conn].env
  }

  # Cleanup steps
  # Delete the CloudTrail trail
  step "container" "delete_cloudtrail_trail" {
    depends_on = [step.container.empty_s3_bucket]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "cloudtrail", "delete-trail",
      "--name", param.trail_name,
      "--region", param.region
    ]
    env = connection.aws[param.conn].env
  }

  # Delete the KMS key after the CloudTrail trail has been deleted
  step "container" "schedule_kms_key_deletion" {
    depends_on = [step.container.delete_cloudtrail_trail]
    image      = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "kms", "schedule-key-deletion",
      "--key-id", jsondecode(step.container.create_kms_key.stdout).KeyMetadata.KeyId,
      "--pending-window-in-days", "7",
      "--region", param.region
    ]
    env = connection.aws[param.conn].env
  }

  # Delete the S3 bucket after it has been emptied
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.container.schedule_kms_key_deletion]
    pipeline   = aws.pipeline.delete_s3_bucket
    args = {
      bucket = param.s3_bucket
      conn   = param.conn
      region = param.region
    }
  }
}
