mod "aws_compliance" {
  title         = "AWS Compliance"
  description   = "Run pipelines to detect and correct AWS resources that are non-compliant."
  color         = "#FF9900"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/aws-compliance.svg"
  categories    = ["aws", "compliance", "public cloud"]

  opengraph {
    title       = "AWS Compliance Mod for Flowpipe"
    description = "Run pipelines to detect and correct AWS resources that are non-compliant."
    image       = "/images/mods/turbot/aws-compliance-social-graphic.png"
  }

  require {
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "0.1.1-rc.0"
    }
    mod "github.com/turbot/flowpipe-mod-aws" {
      version = "0.5.0-rc.5"
    }
  }
}
