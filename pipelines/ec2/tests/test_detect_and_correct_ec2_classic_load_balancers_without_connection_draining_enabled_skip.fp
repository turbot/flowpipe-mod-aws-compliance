pipeline "test_detect_and_correct_ec2_classic_load_balancers_without_connection_draining_enabled_skip" {
  title       = "Test EC2 classic load balancer without connection draining enabled"
  description = "Test the detect_and_correct_ec2_classic_load_balancers_without_connection_draining_enabled pipeline."

  tags = {
    type = "test"
  }

  param "cred" {
    type        = string
    description = local.description_credential
    default     = "default"
  }

  param "region" {
    type        = string
    description = local.description_region
    default    = "us-east-1"
  }

  param "elb_name" {
    type        = string
    description = "ELB Name"
    default    = "flowpipe-test"
  }

  param "availability_zones" {
    type        = list(string)
    description = "availability_zones"
    default    = ["us-east-1a"]
  }

  param "listeners" {
    type        = list(map(any))
    description = "A list of listener configurations. Each listener configuration should include 'Protocol', 'LoadBalancerPort', 'InstanceProtocol', and 'InstancePort'."
    default = [
      {
        Protocol          = "HTTP"
        LoadBalancerPort  = 80  # Must be passed as a string here but converted later
        InstanceProtocol  = "HTTP"
        InstancePort      = 80  # Must be passed as a string here but converted later
      }
    ]
  }

	step "pipeline" "create_elb_classic_load_balancer" {
    pipeline = local.aws_pipeline_create_elb_classic_load_balancer
    args = {
      region   = param.region
      cred    = param.cred
      name = param.elb_name
      listeners = param.listeners
      availability_zones = param.availability_zones
    }
  }

  step "pipeline" "run_detection" {
    depends_on = [step.pipeline.create_elb_classic_load_balancer]
    pipeline = pipeline.detect_and_correct_ec2_classic_load_balancers_without_connection_draining_enabled
    args = {
      default_action  = "skip"
      enabled_actions = ["skip"]
      approvers       = []
    }
  }

  step "query" "get_elb_classic_load_balancer" {
    depends_on = [step.pipeline.run_detection]
    database = var.database
    sql = <<-EOQ
      select
        *
      from
        aws_ec2_classic_load_balancer
      where
        name = 'flowpipe-test'
        and  not connection_draining_enabled;
    EOQ
  }

 step "pipeline" "delete_elb_load_balancer" {
    depends_on = [step.query.get_elb_classic_load_balancer]
    pipeline  = local.aws_pipeline_delete_elb_load_balancer
    args = {
      cred    = param.cred
      load_balancer_name = param.elb_name
      region   = param.region
    }
  }

  output "test_results" {
    description = "Test results for each step."
    value = {
      "create_elb_classic_load_balancer" = !is_error(step.pipeline.create_elb_classic_load_balancer) ? "pass" : "fail: ${error_message(step.pipeline.create_elb_classic_load_balancer)}"
      "get_elb_classic_load_balancer" = length(step.query.get_elb_classic_load_balancer.rows) == 1 ? "pass" : "fail: Row length is not 1"
      "delete_elb_load_balancer" = !is_error(step.pipeline.delete_elb_load_balancer) ? "pass" : "fail: ${error_message(step.pipeline.delete_elb_load_balancer)}"
    }
  }
}
