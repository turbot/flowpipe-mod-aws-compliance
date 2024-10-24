mod "aws_compliance" {
  title         = "AWS Compliance"
  description   = "Run pipelines to detect and correct AWS resources that are non-compliant."
  color         = "#FF9900"
  documentation = file("./README.md")
  database      = var.database
  icon          = "/images/mods/turbot/aws-compliance.svg"
  categories    = ["aws", "compliance", "public cloud", "standard"]

  opengraph {
    title       = "AWS Compliance Mod for Flowpipe"
    description = "Run pipelines to detect and correct AWS resources that are non-compliant."
    image       = "/images/mods/turbot/aws-compliance-social-graphic.png"
  }

  require {
    flowpipe {
      min_version = "1.0.0"
    }
    mod "github.com/turbot/flowpipe-mod-detect-correct" {
      version = "^1"
    }
    mod "github.com/turbot/flowpipe-mod-aws" {
      version = "^1"
    }
  }
}
