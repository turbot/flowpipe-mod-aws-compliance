// Tags
locals {
  aws_compliance_common_tags = {
    category = "Compliance"
    mod      = "aws"
    service  = "AWS"
  }
}

// Consts
locals {
  level_error   = "error"
  level_info    = "info"
  level_verbose = "verbose"
  style_alert   = "alert"
  style_info    = "info"
  style_ok      = "ok"
}

// Common Texts
locals {
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_database         = "Database connection string."
  description_default_action   = "The default action to use when there are no approvers."
  description_enabled_actions  = "The list of enabled actions approvers can select."
  description_items            = "A collection of detected resources to run corrective actions against."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_region           = "AWS Region of the resource(s)."
  description_resource         = "The name of the resource"
  description_title            = "Title of the resource, to be used as a display name."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
}

// Pipeline References
locals {
  pipeline_optional_message                         = detect_correct.pipeline.optional_message
  // aws_pipeline_modify_launch_template              = aws.pipeline.modify_launch_template
  aws_pipeline_attach_log_group_to_cloudtrail_trail = aws.pipeline.update_cloudtrail_trail
  aws_pipeline_attach_polict_to_role                = aws.pipeline.attach_iam_role_policy
  aws_pipeline_create_cloudtrail_trail              = aws.pipeline.create_cloudtrail_trail
  aws_pipeline_create_cloudwatch_log_group          = aws.pipeline.create_cloudwatch_log_group
  aws_pipeline_create_ebs_snapshot                  = aws.pipeline.create_ebs_snapshot
  aws_pipeline_create_elb_classic_load_balancer     = aws.pipeline.create_elb_classic_load_balancer
  aws_pipeline_create_iam_access_analyzer           = aws.pipeline.create_iam_access_analyzer
  aws_pipeline_create_iam_policy                    = aws.pipeline.create_iam_policy
  aws_pipeline_create_iam_role_with_policy          = aws.pipeline.create_iam_role
  aws_pipeline_create_s3_bucket                     = aws.pipeline.create_s3_bucket
  aws_pipeline_create_vpc_flow_logs                 = aws.pipeline.create_vpc_flow_logs
  aws_pipeline_delete_dynamodb_table                = aws.pipeline.delete_dynamodb_table
  aws_pipeline_delete_ebs_snapshot                  = aws.pipeline.delete_ebs_snapshot
  aws_pipeline_delete_elb_load_balancer             = aws.pipeline.delete_elb_load_balancer
  aws_pipeline_delete_iam_access_key                = aws.pipeline.delete_iam_access_key
  aws_pipeline_delete_network_acl_entry             = aws.pipeline.delete_network_acl_entry
  aws_pipeline_delete_s3_bucket                     = aws.pipeline.delete_s3_bucket
  aws_pipeline_detach_network_interface             = aws.pipeline.detach_network_interface
  aws_pipeline_enable_cloudtrail_validation         = aws.pipeline.update_cloudtrail_trail
  aws_pipeline_enable_ebs_volume_encryption         = aws.pipeline.enable_ebs_encryption_by_default
  aws_pipeline_enable_kms_key_rotation              = aws.pipeline.enable_kms_key_rotation
  aws_pipeline_enable_security_hub                  = aws.pipeline.enable_security_hub
  aws_pipeline_modify_apigateway_rest_api_stage     = aws.pipeline.modify_apigateway_rest_api_stage
  aws_pipeline_modify_ebs_snapshot                  = aws.pipeline.modify_ebs_snapshot
  aws_pipeline_modify_ec2_instance_metadata_options = aws.pipeline.modify_ec2_instance_metadata_options
  aws_pipeline_modify_elb_attributes                = aws.pipeline.modify_elb_attributes
  aws_pipeline_modify_rds_db_cluster                = aws.pipeline.modify_rds_db_cluster
  aws_pipeline_modify_rds_db_instance               = aws.pipeline.modify_rds_db_instance
  aws_pipeline_put_alternate_contact                = aws.pipeline.put_alternate_contact
  aws_pipeline_put_cloudtrail_trail_event_selectors = aws.pipeline.put_cloudtrail_trail_event_selector
  aws_pipeline_put_kms_key_policy                   = aws.pipeline.put_kms_key_policy
  aws_pipeline_put_s3_bucket_encryption             = aws.pipeline.put_s3_bucket_encryption
  aws_pipeline_put_s3_bucket_logging                = aws.pipeline.put_s3_bucket_logging
  aws_pipeline_put_s3_bucket_policy                 = aws.pipeline.put_s3_bucket_policy
  aws_pipeline_put_s3_bucket_public_access_block    = aws.pipeline.put_s3_bucket_public_access_block
  aws_pipeline_revoke_vpc_security_group_ingress    = aws.pipeline.revoke_vpc_security_group_ingress
  aws_pipeline_s3_bucket_block_public_access        = aws.pipeline.put_s3_bucket_public_access_block
  aws_pipeline_start_cloudtrail_trail_logging       = aws.pipeline.start_cloudtrail_trail_logging
  aws_pipeline_terminate_ec2_instances              = aws.pipeline.terminate_ec2_instances
  aws_pipeline_update_cloudtrail_trail              = aws.pipeline.update_cloudtrail_trail
  aws_pipeline_update_dynamodb_continuous_backup    = aws.pipeline.update_dynamodb_continuous_backup
  aws_pipeline_update_dynamodb_table                = aws.pipeline.update_dynamodb_table
  aws_pipeline_update_iam_account_password_policy   = aws.pipeline.update_iam_account_password_policy
}