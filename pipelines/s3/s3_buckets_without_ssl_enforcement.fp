locals {
  s3_buckets_without_ssl_enforcement_query = <<-EOQ
    with ssl_ok as (
      select
        distinct name,
        arn
      from
        aws_s3_bucket,
        jsonb_array_elements(policy_std -> 'Statement') as s,
        jsonb_array_elements_text(s -> 'Principal' -> 'AWS') as p,
        jsonb_array_elements_text(s -> 'Action') as a,
        jsonb_array_elements_text(s -> 'Resource') as r,
        jsonb_array_elements_text(
          s -> 'Condition' -> 'Bool' -> 'aws:securetransport'
        ) as ssl
      where
        p = '*'
        and s ->> 'Effect' = 'Deny'
        and ssl::bool = false
    )
    select
      concat(b.name, ' [', b.account_id, '/', b.region, ']') as title,
      b.name as bucket_name,
      b.sp_connection_name as conn,
      b.region
    from
      aws_s3_bucket as b
      left join ssl_ok as ok on ok.name = b.name
    where
      ok.name is null;
  EOQ
}

variable "s3_bucket_enforce_ssl_trigger_enabled" {
  type        = bool
  default     = false
  description = "If true, the trigger is enabled."

  tags = {
    folder = "Advanced/S3"
  }
}

variable "s3_bucket_enforce_ssl_trigger_schedule" {
  type        = string
  default     = "15m"
  description = "If the trigger is enabled, run it on this schedule."

  tags = {
    folder = "Advanced/S3"
  }
}

variable "s3_bucket_enforce_ssl_default_action" {
  type        = string
  description = "The default action to use when there are no approvers."
  default     = "notify"

  tags = {
    folder = "Advanced/S3"
  }
}

variable "s3_bucket_enforce_ssl_enabled_actions" {
  type        = list(string)
  description = "The list of enabled actions approvers can select."
  default     = ["skip", "enforce_ssl"]

  tags = {
    folder = "Advanced/S3"
  }
}

trigger "query" "detect_and_correct_s3_buckets_without_ssl_enforcement" {
  title       = "Detect & correct S3 buckets without SSL enforcement"
  description = "Detect S3 buckets that do not enforce SSL and then skip or enforce SSL."
  tags        = local.s3_common_tags

  enabled  = var.s3_bucket_enforce_ssl_trigger_enabled
  schedule = var.s3_bucket_enforce_ssl_trigger_schedule
  database = var.database
  sql      = local.s3_buckets_without_ssl_enforcement_query

  capture "insert" {
    pipeline = pipeline.correct_s3_buckets_without_ssl_enforcement
    args = {
      items = self.inserted_rows
    }
  }
}

pipeline "detect_and_correct_s3_buckets_without_ssl_enforcement" {
  title       = "Detect & correct S3 buckets without SSL enforcement"
  description = "Detect S3 buckets that do not enforce SSL and then skip or enforce SSL."
  tags        = merge(local.s3_common_tags, { recommended = "true" })

  param "database" {
    type        = connection.steampipe
    description = local.description_database
    default     = var.database
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "query" "detect" {
    database = param.database
    sql      = local.s3_buckets_without_ssl_enforcement_query
  }

  step "pipeline" "respond" {
    pipeline = pipeline.correct_s3_buckets_without_ssl_enforcement
    args = {
      items              = step.query.detect.rows
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_s3_buckets_without_ssl_enforcement" {
  title       = "Correct S3 buckets without SSL enforcement"
  description = "Executes corrective actions on S3 buckets that do not enforce SSL."
  tags        = merge(local.s3_common_tags, { type = "internal" })

  param "items" {
    type = list(object({
      title       = string
      bucket_name = string
      region      = string
      conn        = string
    }))
    description = local.description_items
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "message" "notify_detection_count" {
    if       = var.notification_level == local.level_info
    notifier = param.notifier
    text     = "Detected ${length(param.items)} S3 bucket(s) without SSL enforcement."
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in param.items : item.bucket_name => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_s3_bucket_without_ssl_enforcement
    args = {
      title              = each.value.title
      bucket_name        = each.value.bucket_name
      region             = each.value.region
      conn               = connection.aws[each.value.conn]
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
    }
  }
}

pipeline "correct_one_s3_bucket_without_ssl_enforcement" {
  title       = "Correct one S3 bucket without SSL enforcement"
  description = "Enforces SSL on a single S3 bucket."
  tags        = merge(local.s3_common_tags, { type = "internal" })

  param "title" {
    type        = string
    description = local.description_title
  }

  param "bucket_name" {
    type        = string
    description = "The name of the S3 bucket."
  }

  param "region" {
    type        = string
    description = local.description_region
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
  }

  param "notifier" {
    type        = notifier
    description = local.description_notifier
    default     = var.notifier
  }

  param "notification_level" {
    type        = string
    description = local.description_notifier_level
    default     = var.notification_level
  }

  param "approvers" {
    type        = list(notifier)
    description = local.description_approvers
    default     = var.approvers
  }

  param "default_action" {
    type        = string
    description = local.description_default_action
    default     = var.s3_bucket_enforce_ssl_default_action
  }

  param "enabled_actions" {
    type        = list(string)
    description = local.description_enabled_actions
    default     = var.s3_bucket_enforce_ssl_enabled_actions
  }

  step "pipeline" "respond" {
    pipeline = detect_correct.pipeline.correction_handler
    args = {
      notifier           = param.notifier
      notification_level = param.notification_level
      approvers          = param.approvers
      detect_msg         = "Detected S3 bucket ${param.bucket_name} without SSL enforcement."
      default_action     = param.default_action
      enabled_actions    = param.enabled_actions
      actions = {
        "skip" = {
          label        = "Skip"
          value        = "skip"
          style        = local.style_info
          pipeline_ref = detect_correct.pipeline.optional_message
          pipeline_args = {
            notifier = param.notifier
            send     = param.notification_level == local.level_verbose
            text     = "Skipped S3 bucket ${param.bucket_name} without SSL enforcement."
          }
          success_msg = "Skipped S3 bucket ${param.bucket_name} without SSL enforcement."
          error_msg   = "Error skipping S3 bucket ${param.bucket_name} without SSL enforcement."
        },
        "enforce_ssl" = {
          label        = "Add bucket policy statement to enforce SSL to S3 bucket ${param.bucket_name}"
          value        = "enforce_ssl"
          style        = local.style_alert
          pipeline_ref = pipeline.put_s3_bucket_policy
          pipeline_args = {
            bucket      = param.bucket_name
            region      = param.region
            conn        = param.conn
            policy      = <<EOF
            {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Deny",
                  "Principal": "*",
                  "Action": "s3:*",
                  "Resource": [],
                  "Condition": {
                    "Bool": {
                      "aws:SecureTransport": "false"
                    }
                  }
                }
              ]
            }
            EOF
          }
          success_msg = "Added bucket policy statement to enforce SSL to S3 bucket ${param.bucket_name}."
          error_msg   = "Failed to add bucket policy statement to enforce SSL to S3 bucket ${param.bucket_name}."
        }
      }
    }
  }
}

pipeline "put_s3_bucket_policy" {
  title       = "Put or Append to S3 bucket Policy"
  description = "Appends a new policy statement to an existing S3 bucket policy or creates one if it doesn't exist."

  param "region" {
    type        = string
    description = "The AWS region in which the S3 bucket is located."
  }

  param "conn" {
    type        = string
    description = "The AWS connection profile to use."
    default     = connection.aws.default
  }

  param "bucket" {
    type        = string
    description = "The name of the S3 bucket."
  }

  param "policy" {
    type        = string
    description = "The base template for the new policy statement without bucket interpolation."

  }

  step "container" "get_s3_bucket_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = ["s3api", "get-bucket-policy", "--bucket", param.bucket, "--query", "Policy", "--output", "json"]
    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })

    error {
      if      = length(regexall("NoSuchBucketPolicy", result.errors[0].error.detail)) > 0
      ignore  = true
    }
  }

  step "transform" "decode_existing_policy_no_policy" {
    value = try(jsondecode(step.container.get_s3_bucket_policy.stdout), {})
  }

  step "transform" "decode_existing_policy_with_policy" {
    value = try(jsondecode(step.transform.decode_existing_policy_no_policy.value), {})
  } 
  
  step "transform" "prepare_new_statement" {
    value = jsondecode(param.policy).Statement[0]
  }

  step "transform" "concatenate_policies" {
    value = jsonencode({
      Version = coalesce(
        try(step.transform.decode_existing_policy_with_policy.value.Version, "2012-10-17"),
        "2012-10-17"
      )
      Statement = concat(
        try(
          step.transform.decode_existing_policy_with_policy.value.Statement,
          []
        ),
        [
          {
            Effect   = step.transform.prepare_new_statement.value.Effect
            Principal = step.transform.prepare_new_statement.value.Principal
            Action   = step.transform.prepare_new_statement.value.Action
            Resource = [
              "arn:aws:s3:::${param.bucket}",
              "arn:aws:s3:::${param.bucket}/*"
            ]
            Condition = step.transform.prepare_new_statement.value.Condition
          }
        ]
      )
    })
  }

  step "container" "put_s3_bucket_policy" {
    image = "public.ecr.aws/aws-cli/aws-cli"
    cmd = [
      "s3api", "put-bucket-policy",
      "--bucket", param.bucket,
      "--policy", step.transform.concatenate_policies.value
    ]
    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  output "concatenated_policy_output" {
    value = step.transform.concatenate_policies.value
  }
}
