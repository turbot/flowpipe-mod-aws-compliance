pipeline "test_detect_and_correct_rds_db_instances_with_public_access_enabled" {
  title       = "Test detect and correct RDS DB instances with public access enabled"
  description = "Test the disable public access action for RDS DB instances with public access enabled."

  param "region" {
    type        = string
    description = "The AWS region where the VPC will be created."
    default     = "us-east-1"
  }

  param "conn" {
    type        = connection.aws
    description = local.description_connection
    default     = connection.aws.default
  }

  param "db_instance_identifier" {
    type        = string
    description = "A unique identifier for the DB instance."
    default     = "flowpipe-rds-db-instance-${uuid()}"
  }

  param "db_instance_class" {
    type        = string
    description = "The compute and memory capacity of the DB instance."
    default     = "db.t3.micro"
  }

  param "engine" {
    type        = string
    description = "The database engine to use (e.g., mysql, postgres)."
    default     = "mysql"
  }

  param "master_username" {
    type        = string
    description = "The username for the master user of the database."
    default     = "admin123"
  }

  param "master_user_password" {
    type        = string
    description = "The password for the master user of the database."
    default     = "fp${uuid()}"
  }

  param "allocated_storage" {
    type        = number
    description = "The amount of storage in GB to allocate for the database."
    default     = 20
  }

  param "db_name" {
    type        = string
    description = "The name of the database created in the RDS instance."
    default     = "flowpipe123"
  }

  param "backup_retention_period" {
    type        = number
    description = "The number of days to retain automated backups."
    default     = 1
  }

  param "cidr_block" {
    type        = string
    description = "The CIDR block for the VPC."
    default     = "10.0.0.0/16"
  }

  # Step to get the default VPC ID
  step "container" "get_default_vpc" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "describe-vpcs",
      "--filters", "Name=isDefault,Values=true",
      "--query", "Vpcs[0].VpcId",
      "--output", "text"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
  }

  # Step to create an Internet Gateway (IGW) if necessary
  step "container" "create_internet_gateway" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "create-internet-gateway"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.get_default_vpc]
  }

  # Step to attach the Internet Gateway to the default VPC
  step "container" "attach_internet_gateway" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "attach-internet-gateway",
      "--internet-gateway-id", jsondecode(step.container.create_internet_gateway.stdout).InternetGateway.InternetGatewayId,
      "--vpc-id", step.container.get_default_vpc.stdout
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.create_internet_gateway]
  }

  # Step to get the default security group ID for the default VPC
  step "container" "get_default_security_group" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "describe-security-groups",
      "--filters", format("Name=vpc-id,Values=%s", trimspace(step.container.get_default_vpc.stdout)),
      "Name=group-name,Values=default",
      "--query", "SecurityGroups[0].GroupId",
      "--output", "text"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.get_default_vpc]
  }

  # Step to create the RDS DB instance in the default VPC using the default security group
  step "container" "create_rds_db_instance" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "rds", "create-db-instance",
      "--db-instance-identifier", param.db_instance_identifier,
      "--db-instance-class", param.db_instance_class,
      "--engine", param.engine,
      "--master-username", param.master_username,
      "--master-user-password", param.master_user_password,
      "--allocated-storage", tostring(param.allocated_storage),
      "--vpc-security-group-ids", trimspace(step.container.get_default_security_group.stdout),  # Ensure no extra characters
      "--db-name", param.db_name,
      "--backup-retention-period", tostring(param.backup_retention_period),
      "--publicly-accessible"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.get_default_security_group]
  }

  step "sleep" "sleep_60_seconds_after_rds_creation" {
    depends_on = [ step.container.create_rds_db_instance ]
    duration   = "60s"
  }

  step "query" "get_rds_db_instance_details" {
    database   = var.database
    sql        = <<-EOQ
    select
      concat(db_instance_identifier, ' [', account_id, '/', region, ']') as title,
      db_instance_identifier,
      region,
      sp_connection_name as conn
    from
      aws_rds_db_instance
    where
      db_instance_identifier = '${param.db_instance_identifier}'
      and publicly_accessible;
    EOQ
  }

  step "pipeline" "correct_item" {
    for_each        = { for item in step.query.get_rds_db_instance_details.rows : item.title => item }
    max_concurrency = var.max_concurrency
    pipeline        = pipeline.correct_one_rds_db_instance_with_public_access_enabled
    args = {
      title                  = each.value.title
      db_instance_identifier = each.value.db_instance_identifier
      region                 = each.value.region
      conn                   = connection.aws[each.value.conn]
      approvers              = []
      default_action         = "disable_public_access"
      enabled_actions        = ["disable_public_access"]
    }
  }

  step "sleep" "sleep_60_seconds_after_remediation" {
    depends_on = [ step.pipeline.correct_item ]
    duration   = "60s"
  }

  step "query" "get_rds_db_instance_details_after_remediation" {
    depends_on = [step.pipeline.correct_item]
    database   = var.database
    sql        = <<-EOQ
    select
      concat(db_instance_identifier, ' [', account_id, '/', region, ']') as title,
      db_instance_identifier,
      region,
      sp_connection_name as conn
    from
      aws_rds_db_instance
    where
      db_instance_identifier = '${param.db_instance_identifier}'
      and publicly_accessible;
    EOQ
  }

  output "query_output_result_after_remediation" {
    value = step.query.get_rds_db_instance_details_after_remediation
  }

  output "result" {
    description = "Result of action verification."
    value       = length(step.query.get_rds_db_instance_details_after_remediation.rows) == 0 ? "pass" : "fail"
  }

  step "sleep" "sleep_60_seconds_after_verification" {
    depends_on = [ step.query.get_rds_db_instance_details_after_remediation ]
    duration   = "60s"
  }

  # Step to delete the RDS DB instance
  step "container" "delete_rds_db_instance" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "rds", "delete-db-instance",
      "--db-instance-identifier", param.db_instance_identifier,
      "--skip-final-snapshot"
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.query.get_rds_db_instance_details_after_remediation]
  }

  # Step to detach the Internet Gateway from the VPC
  step "container" "detach_internet_gateway" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "detach-internet-gateway",
      "--internet-gateway-id", jsondecode(step.container.create_internet_gateway.stdout).InternetGateway.InternetGatewayId,
      "--vpc-id", step.container.get_default_vpc.stdout
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.delete_rds_db_instance]
  }

  # Step to delete the Internet Gateway
  step "container" "delete_internet_gateway" {
    image = "public.ecr.aws/aws-cli/aws-cli"

    cmd = [
      "ec2", "delete-internet-gateway",
      "--internet-gateway-id", jsondecode(step.container.create_internet_gateway.stdout).InternetGateway.InternetGatewayId
    ]

    env = merge(connection.aws[param.conn].env, { AWS_REGION = param.region })
    depends_on = [step.container.detach_internet_gateway]
  }

}

