pipeline "test_ec2_instances_with_imdsv1_enabled" {
  title       = "Test EC2 instances with IMDSv1 enabled"
  description = "Tests the detection and correction of EC2 instances with IMDSv1 enabled."

  tags = {
    folder = "Tests"
  }

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

  param "ami_id" {
    type        = string
    description = "The AMI ID to use for the EC2 instance."
    default     = "ami-0c94855ba95c71c99" // corresponds to the Amazon Linux 2 AMI (HVM), SSD Volume Type in the us-east-1, you can change this to any valid AMI ID
  }

  param "instance_type" {
    type        = string
    description = "The EC2 instance type."
    default     = "t2.micro"
  }

  param "instance_name" {
    type        = string
    description = "The name of the EC2 instance."
    default     = "test-imdsv2-instance-${uuid()}"
  }

  param "subnet_id" {
    type        = string
    description = "The subnet ID to use for the creation of the EC2 instance."
    default     = "" // must be a valid subnet ID
  }

  # Step to create an EC2 instance with HttpTokens set to 'optional' (IMDSv1 enabled)
  step "container" "create_ec2_instance" {
    image = "amazon/aws-cli:latest"

    cmd = [
      "ec2", "run-instances",
      "--image-id", param.ami_id,
      "--instance-type", param.instance_type,
      "--subnet-id", param.subnet_id,
      "--metadata-options", "HttpTokens=optional",
      "--region", param.region,
      "--output", "json",
    ]

    env = connection.aws[param.conn].env
  }

  # Wait for the EC2 instance to be in 'running' state
  step "container" "wait_for_instance_running" {
    depends_on = [step.container.create_ec2_instance]
    image      = "amazon/aws-cli:latest"

    cmd = [
      "ec2", "wait", "instance-running",
      "--instance-ids", jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId,
      "--region", param.region
    ]

    env = connection.aws[param.conn].env
  }

  step "query" "ec2_instances_without_imdsv2" {
    depends_on = [step.container.wait_for_instance_running]
    database   = var.database
    sql        = <<-EOQ
      select
      concat(instance_id, ' [', account_id, '/', region, ']') as title,
      instance_id,
      region,
      sp_connection_name as conn
    from
      aws_ec2_instance
    where
      instance_id = '${jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId}'
      and metadata_options ->> 'HttpTokens' = 'optional';
    EOQ
  }

  # Use the existing pipeline to modify instance metadata options
  step "pipeline" "run_correction_pipeline" {
    if       = length(step.query.ec2_instances_without_imdsv2.rows) == 1
    pipeline = pipeline.correct_one_ec2_instance_with_imdsv1_enabled

    args = {
      title           = step.query.ec2_instances_without_imdsv2.rows[0].title
      instance_id     = jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId
      region          = param.region
      conn            = param.conn
      approvers       = []
      default_action  = "disable_imdsv1"
      enabled_actions = ["disable_imdsv1"]
    }
  }

  # Verify that HttpTokens is now set to 'required' (IMDSv2 enforced) using a Steampipe query
  step "query" "verify_imdsv2" {
    depends_on = [step.pipeline.run_correction_pipeline]
    database   = var.database
    sql        = <<-EOQ
      select
        instance_id,
        metadata_options ->> 'HttpTokens' as http_tokens
      from
        aws_ec2_instance
      where
        instance_id = '${jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId}'
        and metadata_options ->> 'HttpTokens' = 'required';
    EOQ
  }

  output "result" {
    value = length(step.query.verify_imdsv2.rows) == 1 ? "IMDSv1 disabled on EC2 instance." : "IMDSv1 enabled on EC2 instance."
  }

  # Terminate the EC2 instance
  step "pipeline" "terminate_ec2_instance" {
    depends_on = [step.query.verify_imdsv2]
    pipeline   = aws.pipeline.terminate_ec2_instances

    args = {
      instance_ids = [jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId]
      region       = param.region
      conn         = param.conn
    }
  }
}
