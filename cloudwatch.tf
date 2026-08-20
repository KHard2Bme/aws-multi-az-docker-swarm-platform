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
#
# Managers and workers retrieve the same
# configuration during bootstrap.
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
# Combines:
# - EC2 infrastructure metrics
# - CloudWatch Agent custom metrics
# - Docker failure metrics
# - ALB health and traffic metrics
#############################################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [

      #################################################
      # EC2 Infrastructure Metrics
      #################################################

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

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Manager Network In"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300

          metrics = [
            for i in aws_instance.managers :
            [
              "AWS/EC2",
              "NetworkIn",
              "InstanceId",
              i.id
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          title  = "Manager Network Out"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 300

          metrics = [
            for i in aws_instance.managers :
            [
              "AWS/EC2",
              "NetworkOut",
              "InstanceId",
              i.id
            ]
          ]
        }
      },

      #################################################
      # Worker CloudWatch Agent Metrics
      #################################################

      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
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

      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          title  = "Worker CPU Idle"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "cpu_usage_idle"
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "Worker Memory Utilization"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "mem_used_percent"
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6

        properties = {
          title  = "Worker Network Traffic"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "EngineeringForFailure",
              "bytes_sent"
            ],
            [
              ".",
              "bytes_recv"
            ]
          ]
        }
      },

      #################################################
      # Docker Failure Metrics
      #################################################

      {
        type   = "metric"
        x      = 0
        y      = 24
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

      {
        type   = "metric"
        x      = 8
        y      = 24
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

      {
        type   = "metric"
        x      = 16
        y      = 24
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

      #################################################
      # Application Load Balancer Metrics
      #################################################

      {
        type   = "metric"
        x      = 0
        y      = 30
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
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 30
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
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 36
        width  = 12
        height = 6

        properties = {
          title  = "ALB Request Count"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "RequestCount",
              "LoadBalancer",
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 36
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target Response Time"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Average"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "TargetResponseTime",
              "LoadBalancer",
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 42
        width  = 12
        height = 6

        properties = {
          title  = "ALB HTTP 5XX Errors"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_ELB_5XX_Count",
              "LoadBalancer",
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 42
        width  = 12
        height = 6

        properties = {
          title  = "ALB Target 5XX Errors"
          view   = "timeSeries"
          region = var.aws_region
          stat   = "Sum"
          period = 60

          metrics = [
            [
              "AWS/ApplicationELB",
              "HTTPCode_Target_5XX_Count",
              "LoadBalancer",
              aws_lb.engineering_for_failure.arn_suffix
            ]
          ]
        }
      }
    ]
  })
}