pipeline "test_ec2_instances_without_imdsv2" {
  title       = "Test EC2 Instances Without IMDSv2"
  description = "Tests the detection and correction of EC2 instances without IMDSv2."

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
    default     = "ami-0c94855ba95c71c99" // Adjust as needed
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

  # Step to create an EC2 instance (HttpTokens defaults to 'optional')
  step "pipeline" "create_ec2_instance" {
    pipeline = aws.pipeline.run_ec2_instances

    args = {
      instance_type = param.instance_type
      image_id      = param.ami_id
      count         = 1
      region        = param.region
      cred          = param.cred
    }

    output "instance_id" {
      value = self.output.instances[0].instance_id
    }
  }

  # Wait for the instance to be in 'running' state
  step "pipeline" "wait_for_instance" {
    depends_on = [step.pipeline.create_ec2_instance]
    pipeline   = aws.pipeline.wait_for_ec2_instance_state

    args = {
      instance_ids = [step.pipeline.create_ec2_instance.output.instance_id]
      state        = "running"
      region       = param.region
      cred         = param.cred
    }
  }

  # Ensure that HttpTokens is set to 'optional' (default behavior)
  # Optionally, modify the instance metadata options to set HttpTokens to 'optional' explicitly
  step "pipeline" "set_http_tokens_optional" {
    depends_on = [step.pipeline.wait_for_instance]
    pipeline   = aws.pipeline.modify_ec2_instance_metadata_options

    args = {
      instance_id = step.pipeline.create_ec2_instance.output.instance_id
      http_tokens = "optional"
      region      = param.region
      cred        = param.cred
    }
  }

  # Run the correction pipeline to enforce IMDSv2
  step "pipeline" "modify_metadata_options" {
    depends_on = [step.pipeline.set_http_tokens_optional]
    pipeline   = aws.pipeline.modify_ec2_instance_metadata_options

    args = {
      instance_id = step.pipeline.create_ec2_instance.output.instance_id
      http_tokens = "required"
      region      = param.region
      cred        = param.cred
    }
  }

  # Verify that HttpTokens is now set to 'required' (IMDSv2 enforced)
  step "query" "verify_imdsv2" {
    depends_on = [step.pipeline.modify_metadata_options]
    database   = var.database
    sql = <<-EOQ
      select
        instance_id,
        metadata_options ->> 'HttpTokens' as http_tokens
      from
        aws_ec2_instance
      where
        instance_id = '${step.pipeline.create_ec2_instance.output.instance_id}'
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
      instance_ids = [step.pipeline.create_ec2_instance.output.instance_id]
      region       = param.region
      cred         = param.cred
    }
  }
}