#############################################
# CloudWatch
# Engineering for Failure
#############################################

#############################################
# CloudWatch Log Group
#############################################

resource "aws_cloudwatch_log_group" "docker" {
  name              = "/engineering-for-failure/docker"
  retention_in_days = 14

  tags = {
    Name    = "${var.project_name}-docker-logs"
    Project = var.project_name
  }
}

#############################################
# CloudWatch Agent Configuration
#
# Stored in SSM Parameter Store so that
# managers and Auto Scaling workers can
# retrieve the same configuration.
#############################################

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name        = "/${var.project_name}/cloudwatch/agent-config"
  description = "CloudWatch Agent configuration for Docker Swarm nodes"
  type        = "String"

  value = file("${path.module}/cloudwatch_agent.json")

  tags = {
    Name    = "${var.project_name}-cloudwatch-agent-config"
    Project = var.project_name
  }
}

#############################################
# Container Failure Metric Filter
#############################################

resource "aws_cloudwatch_log_metric_filter" "container_failure" {
  name           = "ContainerFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker.name

  pattern = "\"ContainerFailure\""

  metric_transformation {
    name      = "ContainerFailure"
    namespace = "EngineeringForFailure"
    value     = "1"

    default_value = 0
  }
}

#############################################
# Worker Node Failure Metric Filter
#############################################

resource "aws_cloudwatch_log_metric_filter" "worker_node_failure" {
  name           = "WorkerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker.name

  pattern = "\"WorkerNodeFailure\""

  metric_transformation {
    name      = "WorkerNodeFailure"
    namespace = "EngineeringForFailure"
    value     = "1"

    default_value = 0
  }
}

#############################################
# Manager Node Failure Metric Filter
#############################################

resource "aws_cloudwatch_log_metric_filter" "manager_node_failure" {
  name           = "ManagerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker.name

  pattern = "\"ManagerNodeFailure\""

  metric_transformation {
    name      = "ManagerNodeFailure"
    namespace = "EngineeringForFailure"
    value     = "1"

    default_value = 0
  }
}