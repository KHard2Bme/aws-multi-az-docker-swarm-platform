#############################################
# CloudWatch Monitoring
# Engineering for Failure
#############################################

#############################################
# Docker CloudWatch Log Group
#############################################

resource "aws_cloudwatch_log_group" "docker_logs" {
  name              = "/${var.project_name}/docker"
  retention_in_days = 14

  tags = {
    Name    = "${var.project_name}-docker-logs"
    Project = var.project_name
  }
}

#############################################
# CloudWatch Agent Configuration
#
# Stored in SSM Parameter Store.
# Retrieved by the Swarm node bootstrap scripts.
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
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "\"ContainerFailure\""

  metric_transformation {
    name          = "ContainerFailure"
    namespace     = "EngineeringForFailure"
    value         = "1"
    default_value = 0
  }
}

#############################################
# Worker Node Failure Metric Filter
#############################################

resource "aws_cloudwatch_log_metric_filter" "worker_node_failure" {
  name           = "WorkerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "\"WorkerNodeFailure\""

  metric_transformation {
    name          = "WorkerNodeFailure"
    namespace     = "EngineeringForFailure"
    value         = "1"
    default_value = 0
  }
}

#############################################
# Manager Node Failure Metric Filter
#############################################

resource "aws_cloudwatch_log_metric_filter" "manager_node_failure" {
  name           = "ManagerNodeFailureFilter"
  log_group_name = aws_cloudwatch_log_group.docker_logs.name

  pattern = "\"ManagerNodeFailure\""

  metric_transformation {
    name          = "ManagerNodeFailure"
    namespace     = "EngineeringForFailure"
    value         = "1"
    default_value = 0
  }
}

#############################################
# CloudWatch Dashboard
#
# Focused specifically on:
#
# 1. Manager health
# 2. Worker activity
# 3. Failure detection
# 4. Application availability
#############################################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [

      #############################################
      # 1. Manager CPU Utilization
      #############################################

      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Manager CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300

          metrics = [
            for i in aws_instance.managers :
            [
              "AWS/EC2",
              "CPUUtilization",
              "InstanceId",
              i.id
            ]
          ]
        }
      },

      #############################################
      # 2. Manager Status Checks
      #############################################

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Manager Status Checks"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Maximum"
          period = 300

          metrics = [
            for i in aws_instance.managers :
            [
              "AWS/EC2",
              "StatusCheckFailed",
              "InstanceId",
              i.id
            ]
          ]
        }
      },

      #############################################
      # 3. Worker CPU Usage
      #
      # CloudWatch Agent custom metrics
      #############################################

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          title  = "Worker CPU Usage"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "cpu_usage_user"
            ],
            [
              ".",
              "cpu_usage_system"
            ]
          ]
        }
      },

      #############################################
      # 4. Container Failures
      #############################################

      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6

        properties = {
          title  = "Container Failures"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "ContainerFailure"
            ]
          ]
        }
      },

      #############################################
      # 5. Worker Node Failures
      #############################################

      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6

        properties = {
          title  = "Worker Node Failures"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "WorkerNodeFailure"
            ]
          ]
        }
      },

      #############################################
      # 6. Manager Node Failures
      #############################################

      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6

        properties = {
          title  = "Manager Node Failures"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "ManagerNodeFailure"
            ]
          ]
        }
      },

      #############################################
      # 7. ALB Healthy Hosts
      #############################################

      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "ALB Healthy Hosts"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HealthyHostCount",
              "TargetGroup",
              aws_lb_target_group.apache.arn_suffix,
              "LoadBalancer",
              aws_lb.application.arn_suffix
            ]
          ]
        }
      },

      #############################################
      # 8. ALB Unhealthy Hosts
      #############################################

      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "ALB Unhealthy Hosts"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "UnHealthyHostCount",
              "TargetGroup",
              aws_lb_target_group.apache.arn_suffix,
              "LoadBalancer",
              aws_lb.application.arn_suffix
            ]
          ]
        }
      }
    ]
  })
}