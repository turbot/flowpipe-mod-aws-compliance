locals {
  kms_common_tags = merge(local.aws_compliance_common_tags, {
    service = "AWS/KMS"
  })
}