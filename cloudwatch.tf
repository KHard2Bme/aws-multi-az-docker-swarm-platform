############################################
# cloudwatch.tf
# CloudWatch resources for Engineering for Failure
############################################

resource "aws_cloudwatch_log_group" "docker_logs" {
  name              = "/engineering-for-failure/docker"
  retention_in_days = 14

  tags = {
    Name = "engineering-for-failure-docker-logs"
  }
}

############################################################
# Container Failure Metric Filter
############################################################

resource "aws_cloudwatch_log_metric_filter" "container_failure" {
  name           = "ContainerFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "ContainerFailure"

  metric_transformation {
    name      = "ContainerFailureCount"
    namespace = "EngineeringForFailure"
    value     = "1"
  }
}

############################################################
# Worker Node Failure Metric Filter
############################################################

resource "aws_cloudwatch_log_metric_filter" "worker_node_failure" {
  name           = "WorkerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "WorkerNodeFailure"

  metric_transformation {
    name      = "WorkerNodeFailureCount"
    namespace = "EngineeringForFailure"
    value     = "1"
  }
}

############################################################
# Manager Node Failure Metric Filter
############################################################

resource "aws_cloudwatch_log_metric_filter" "manager_node_failure" {
  name           = "ManagerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "ManagerNodeFailure"

  metric_transformation {
    name      = "ManagerNodeFailureCount"
    namespace = "EngineeringForFailure"
    value     = "1"
  }
}