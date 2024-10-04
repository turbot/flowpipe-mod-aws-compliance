pipeline "test_ec2_instances_not_requiring_imdsv2" {
  title       = "Test EC2 Instances not requiring IMDSv2"
  description = "Tests the detection and correction of EC2 instances not requiring IMDSv2."

  param "cred" {
    type        = string
    description = "The AWS credential to use."
    default     = "default"
  }

  param "region" {
    type        = string
    description = "The AWS region."
    default     = "us-east-1"
  }

  param "ami_id" {
    type        = string
    description = "The AMI ID to use for the EC2 instance."
    default     = "ami-0c94855ba95c71c99"
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

  # Step to create a VPC
  step "pipeline" "create_vpc" {
    pipeline = aws.pipeline.create_vpc

    args = {
      region     = param.region
      cred       = param.cred
      cidr_block = "10.0.0.0/16"
    }
  }

  # Step to create a subnet
  step "pipeline" "create_vpc_subnet" {
    depends_on = [step.pipeline.create_vpc]
    pipeline   = aws.pipeline.create_vpc_subnet

    args = {
      region     = param.region
      cred       = param.cred
      vpc_id     = step.pipeline.create_vpc.output.vpc.VpcId
      cidr_block = "10.0.1.0/24"
    }
  }

  # Step to create an EC2 instance with HttpTokens set to 'optional' (IMDSv1 enabled)
  step "container" "create_ec2_instance" {
    depends_on = [
      step.pipeline.create_vpc_subnet
    ]
    image = "amazon/aws-cli:latest"

    cmd = [
      "ec2", "run-instances",
      "--image-id", param.ami_id,
      "--instance-type", param.instance_type,
      "--subnet-id", step.pipeline.create_vpc_subnet.output.subnet.SubnetId,
      "--metadata-options", "HttpTokens=optional",
      "--region", param.region,
      "--output", "json",
    ]

    env = credential.aws[param.cred].env
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

    env = credential.aws[param.cred].env
  }

  # Use the existing pipeline to modify instance metadata options
  step "pipeline" "modify_metadata_options" {
    depends_on = [step.container.wait_for_instance_running]
    pipeline   = aws.pipeline.modify_ec2_instance_metadata_options

    args = {
      instance_id = jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId
      http_tokens = "required"
      region      = param.region
      cred        = param.cred
    }
  }

  # Verify that HttpTokens is now set to 'required' (IMDSv2 enforced) using a Steampipe query
  step "query" "verify_imdsv2" {
    depends_on = [step.pipeline.modify_metadata_options]
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
    value = length(step.query.verify_imdsv2.rows) == 1 ? "IMDSv2 enabled on EC2 instance." : "IMDSv2 not enabled on EC2 instance."
  }

  # Terminate the EC2 instance
  step "pipeline" "terminate_ec2_instance" {
    depends_on = [step.query.verify_imdsv2]
    pipeline   = aws.pipeline.terminate_ec2_instances

    args = {
      instance_ids = [jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId]
      region       = param.region
      cred         = param.cred
    }
  }

  # Cleanup steps to delete resources

step "container" "wait_for_instance_termination" {
  depends_on = [step.pipeline.terminate_ec2_instance]
  image      = "amazon/aws-cli:latest"

  cmd = [
    "ec2", "wait", "instance-terminated",
    "--instance-ids", jsondecode(step.container.create_ec2_instance.stdout).Instances[0].InstanceId,
    "--region", param.region
  ]

  env = credential.aws[param.cred].env
}

  # Delete the subnet
  step "container" "delete_subnet" {
    depends_on = [step.container.wait_for_instance_termination]
    image      = "amazon/aws-cli:latest"

    cmd = [
      "ec2", "delete-subnet",
      "--subnet-id", step.pipeline.create_vpc_subnet.output.subnet.SubnetId,
      "--region", param.region
    ]

    env = credential.aws[param.cred].env
  }

  # Delete the VPC
  step "container" "delete_vpc" {
    depends_on = [step.container.delete_subnet]
    image      = "amazon/aws-cli:latest"

    cmd = [
      "ec2", "delete-vpc",
      "--vpc-id", step.pipeline.create_vpc.output.vpc.VpcId,
      "--region", param.region
    ]

    env = credential.aws[param.cred].env
  }

}