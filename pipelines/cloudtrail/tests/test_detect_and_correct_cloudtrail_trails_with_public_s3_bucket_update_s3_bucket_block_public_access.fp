pipeline "test_detect_and_correct_cloudtrail_trails_with_public_s3_bucket_update_s3_bucket_block_public_access" {
  title       = "Test detect & correct CloudTrail trails with public S3 bucket"
  description = "Test detect CloudTrail trails with public S3 bucket and then skip or update S3 bucket public access block."

  tags = {
    type = "test"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "region" {
    type        = string
    description = "The AWS region where the resource will be created."
    default     = "us-east-1"
  }

  param "trail_name" {
    type        = string
    description = "The name of the trail."
    default     = "test-fp-s3-with-public-access-trail"
  }

  param "bucket_name" {
    type        = string
    description = "The name of the bucket."
    default     = "test-fp-s3-with-public-access-bucket"
  }

  step "query" "get_account_id" {
    database = var.database
    sql      = <<-EOQ
      select
        account_id
      from
        aws_account;
    EOQ
  }

  step "pipeline" "create_s3_bucket_for_trail_s3_bucket_public_access" {
    depends_on = [step.query.get_account_id]
    pipeline   = aws.pipeline.create_s3_bucket
    args = {
      region = param.region
      conn   = param.conn
      bucket = param.bucket_name
    }
  }

  step "pipeline" "put_s3_bucket_policy" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_s3_bucket_public_access]
    pipeline   = aws.pipeline.put_s3_bucket_policy
    args = {
      region = param.region
      conn   = param.conn
      bucket = param.bucket_name
      policy = "{\"Version\": \"2012-10-17\",\n\"Statement\": [\n{\n\"Sid\":\"AWSCloudTrailAclCheck\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:GetBucketAcl\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}\"\n},\n{\n\"Sid\": \"AWSCloudTrailWrite\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\": \"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutObject\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}/AWSLogs/${step.query.get_account_id.rows[0].account_id}/*\",\n\"Condition\": {\n\"StringEquals\": {\n\"s3:x-amz-acl\":\n\"bucket-owner-full-control\"\n}\n}\n},\n{\n\"Sid\":\"AWSCloudTrailPublicAccessBlock\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"Service\":\"cloudtrail.amazonaws.com\"\n},\n\"Action\": \"s3:PutBucketPublicAccessBlock\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}\"\n},\n{\n\"Sid\":\"Public\",\n\"Effect\": \"Allow\",\n\"Principal\": {\n\"AWS\":\"*\"\n},\n\"Action\": \"s3:PutBucketPublicAccessBlock\",\n\"Resource\": \"arn:aws:s3:::${param.bucket_name}\"\n} \n]\n}"
    }
  }

  step "pipeline" "put_s3_bucket_public_access_block" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_s3_bucket_public_access, step.pipeline.put_s3_bucket_policy]
    pipeline   = aws.pipeline.put_s3_bucket_public_access_block
    args = {
      bucket                  = param.bucket_name
      region                  = param.region
      conn                    = param.conn
      block_public_acls       = false
      ignore_public_acls      = false
      block_public_policy     = false
      restrict_public_buckets = false
    }
  }

  step "pipeline" "create_trail_with_s3_public_access_enabled" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_s3_bucket_public_access, step.pipeline.put_s3_bucket_policy, step.pipeline.put_s3_bucket_public_access_block]
    pipeline   = aws.pipeline.create_cloudtrail_trail
    args = {
      region                        = param.region
      conn                          = param.conn
      name                          = param.trail_name
      bucket_name                   = param.bucket_name
      is_multi_region_trail         = false
      include_global_service_events = false
      enable_log_file_validation    = false
    }
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_s3_bucket_for_trail_s3_bucket_public_access, step.pipeline.put_s3_bucket_policy, step.pipeline.put_s3_bucket_public_access_block, step.pipeline.create_trail_with_s3_public_access_enabled]
    pipeline   = pipeline.correct_one_cloudtrail_trail_with_public_s3_bucket
    args = {
      account_id      = step.query.get_account_id.rows[0].account_id
      title           = "${param.trail_name} [ ${step.query.get_account_id.rows[0].account_id}/${param.region}]'"
      name            = param.trail_name
      bucket_name     = param.bucket_name
      region          = param.region
      account_id      = step.query.get_account_id.rows[0].account_id
      conn            = param.conn
      approvers       = []
      default_action  = "update_s3_bucket_block_public_access"
      enabled_actions = ["update_s3_bucket_block_public_access"]
    }
  }

  step "query" "verify_s3_bucket_public_access_after_detection" {
    depends_on = [step.pipeline.run_detection]
    database   = var.database
    sql        = <<-EOQ
      with public_bucket_data as (
        select
          t.s3_bucket_name as name,
          b.arn,
          t.region,
          t.account_id,
          t.tags,
          t.sp_connection_name,
          count(acl_grant) filter (where acl_grant -> 'Grantee' ->> 'URI' like '%acs.amazonaws.com/groups/global/AllUsers') as all_user_grants,
          count(acl_grant) filter (where acl_grant -> 'Grantee' ->> 'URI' like '%acs.amazonaws.com/groups/global/AuthenticatedUsers') as auth_user_grants,
          count(s) filter (where s ->> 'Effect' = 'Allow' and  p = '*' ) as anon_statements
        from
          aws_cloudtrail_trail as t
          left join aws_s3_bucket as b on t.s3_bucket_name = b.name
          left join jsonb_array_elements(acl -> 'Grants') as acl_grant on true
          left join jsonb_array_elements(policy_std -> 'Statement') as s  on true
          left join jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p  on true
        group by
          t.s3_bucket_name,
          b.arn,
          t.region,
          t.account_id,
          t.tags,
          t.sp_connection_name
      )
      select
        concat(name, ' [', account_id, '/', region, ']') as title,
        name,
        case
          when arn is null then 'arn:aws:s3:::' || name
          else arn
        end as bucket_arn,
        region,
        account_id,
        sp_connection_name as conn
      from
        public_bucket_data
      where
        name = '${param.bucket_name}'
        and all_user_grants > 0
        and auth_user_grants > 0
        and anon_statements > 0;
      EOQ
  }

  step "pipeline" "delete_cloudtrail_trail" {
    depends_on = [step.pipeline.run_detection, step.query.verify_s3_bucket_public_access_after_detection]

    pipeline = aws.pipeline.delete_cloudtrail_trail
    args = {
      conn   = param.conn
      name   = param.trail_name
      region = param.region
    }
  }

  // Cleanup all objects before deleting it.
  step "pipeline" "delete_s3_bucket_all_objects" {
    depends_on = [step.pipeline.run_detection, step.query.verify_s3_bucket_public_access_after_detection, step.pipeline.delete_cloudtrail_trail]

    pipeline = aws.pipeline.delete_s3_bucket_all_objects
    args = {
      conn   = param.conn
      bucket = param.bucket_name
      region = param.region
    }
  }

  // Delete the bucket
  step "pipeline" "delete_s3_bucket" {
    depends_on = [step.pipeline.run_detection, step.query.verify_s3_bucket_public_access_after_detection, step.pipeline.delete_s3_bucket_all_objects]

    pipeline = aws.pipeline.delete_s3_bucket
    args = {
      conn   = param.conn
      bucket = param.bucket_name
      region = param.region
    }
  }

  output "result_trail_with_public_access" {
    description = "Test result for each step"
    value = {
      "get_account_id"                                     = length(step.query.get_account_id.rows) > 0 ? "pass" : "fail"
      "create_s3_bucket_for_trail_s3_bucket_public_access" = !is_error(step.pipeline.create_s3_bucket_for_trail_s3_bucket_public_access) ? "pass" : "fail"
      "put_s3_bucket_policy"                               = !is_error(step.pipeline.put_s3_bucket_policy) ? "pass" : "fali"
      "put_s3_bucket_public_access_block"                  = !is_error(step.pipeline.put_s3_bucket_public_access_block) ? "pass" : "fail"
      "create_trail_with_s3_public_access_enabled"         = !is_error(step.pipeline.create_trail_with_s3_public_access_enabled) ? "pass" : "fail"
      "verify_s3_bucket_public_access_after_detection"     = length(step.query.verify_s3_bucket_public_access_after_detection.rows) == 0 ? "pass" : "fail"
      "delete_cloudtrail_trail"                            = !is_error(step.pipeline.delete_cloudtrail_trail) ? "pass" : "fail"
      "delete_s3_bucket_all_objects"                       = !is_error(step.pipeline.delete_s3_bucket_all_objects) ? "pass" : "fail"
      "delete_s3_bucket"                                   = !is_error(step.pipeline.delete_s3_bucket) ? "pass" : "fail"

    }
  }
}