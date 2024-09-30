locals {
  cloudwatch_common_tags = merge(local.aws_compliance_common_tags, {
    service = "AWS/CloudWatch"
  })
}

variable "log_group_name" {
  type        = string
  description = "The name of the log group to create."
}

variable "region" {
  type        = string
  description = "The region to create the log group in."
}

variable "filter_name" {
  type        = string
  description = "The name of the metric filter."
}

variable "role_name" {
  type        = string
  description = "The name of the IAM role to create."
}

variable "s3_bucket_name" {
  type        = string
  description = "The name of the S3 bucket to which CloudTrail logs will be delivered."
}

variable "metric_name" {
  type        = string
  description = "The name of the metric."
}

variable "metric_namespace" {
  type        = string
  description = "The namespace of the metric."
  default     = "CISBenchmark"
}

variable "queue_name" {
  type        = string
  description = "The name of the SQS queue."
}

variable "metric_value" {
  type        = string
  description = "The value to publish to the metric."
}

variable "filter_pattern" {
  type        = string
  description = "The filter pattern for the metric filter."
}

variable "sns_topic_name" {
  type        = string
  description = "The name of the Amazon SNS topic to create."
}

variable "alarm_name" {
  type        = string
  description = "The name of the CloudWatch alarm."
}

variable "trail_name" {
  type        = string
  description = "The name of the CloudTrail trail."
}

variable "protocol" {
  type        = string
  description = "The protocol to use for the subscription (e.g., email, sms, lambda, etc.)."
}
