// Tags
locals {
  aws_compliance_common_tags = {
    category = "Compliance"
    plugin   = "aws"
    service  = "AWS"
  }
}

// Consts
locals {
  level_verbose = "verbose"
  level_info    = "info"
  level_error   = "error"
  style_ok      = "ok"
  style_info    = "info"
  style_alert   = "alert"
}

// Common Texts
locals {
  description_database         = "Database connection string."
  description_approvers        = "List of notifiers to be used for obtaining action/approval decisions."
  description_credential       = "Name of the credential to be used for any authenticated actions."
  description_region           = "AWS Region of the resource(s)."
  description_title            = "Title of the resource, to be used as a display name."
  description_max_concurrency  = "The maximum concurrency to use for responding to detection items."
  description_notifier         = "The name of the notifier to use for sending notification messages."
  description_notifier_level   = "The verbosity level of notification messages to send. Valid options are 'verbose', 'info', 'error'."
  description_default_action   = "The default action to use for the detected item, used if no input is provided."
  description_enabled_actions  = "The list of enabled actions to provide to approvers for selection."
  description_trigger_enabled  = "If true, the trigger is enabled."
  description_trigger_schedule = "The schedule on which to run the trigger if enabled."
  description_items            = "A collection of detected resources to run corrective actions against."
}

// Pipeline References
locals {
  pipeline_optional_message                               = detect_correct.pipeline.optional_message
  aws_pipeline_modify_apigateway_rest_api_stage           = aws.pipeline.modify_apigateway_rest_api_stage
  aws_pipeline_modify_rds_db_instance                     = aws.pipeline.modify_rds_db_instance
  aws_pipeline_modify_rds_db_cluster                      = aws.pipeline.modify_rds_db_cluster
  aws_pipeline_update_dynamodb_table                      = aws.pipeline.update_dynamodb_table
  aws_pipeline_update_dynamodb_continuous_backup          = aws.pipeline.update_dynamodb_continuous_backup
  aws_pipeline_delete_ebs_snapshot                        = aws.pipeline.delete_ebs_snapshot
  aws_pipeline_modify_ebs_snapshot                        = aws.pipeline.modify_ebs_snapshot
  aws_pipeline_modify_elb_attributes                      = aws.pipeline.modify_elb_attributes
  aws_pipeline_modify_ec2_instance_metadata_options       = aws.pipeline.modify_ec2_instance_metadata_options
  aws_pipeline_terminate_ec2_instances                    = aws.pipeline.terminate_ec2_instances
  aws_pipeline_detach_network_interface                   = aws.pipeline.detach_network_interface
  aws_pipeline_enable_security_hub                        = aws.pipeline.enable_security_hub
}