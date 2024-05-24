mod "aws_compliance" {
  title         = "AWS Compliance"
  description   = "Run pipelines to detect and correct AWS resources that non-compliant."
  color         = "#0089D6"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/aws-compliance.svg"
  categories    = ["aws", "compliance", "public cloud"]

  opengraph {
    title       = "AWS Compliance Mod for Flowpipe"
    description = "Run pipelines to detect and correct AWS resources that non-compliant."
    image       = "/images/mods/turbot/aws-compliance-social-graphic.png"
  }

  require {
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "*"
    }
    mod "github.com/turbot/flowpipe-mod-aws" {
      version = "v0.4.0-rc.22"
    }
  }
}