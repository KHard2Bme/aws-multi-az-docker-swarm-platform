############################################
# iam.tf
# IAM resources for Version 2
#
# Responsibilities:
#   - CloudWatch Agent
#   - CloudWatch dashboard/alarm/log permissions
#   - AWS Systems Manager Session Manager
#   - Docker Swarm Parameter Store bootstrap
############################################

############################################
# EC2 Assume Role Policy
############################################

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

############################################
# EC2 IAM Role
############################################

resource "aws_iam_role" "cloudwatch_agent_role" {
  name               = "${var.project_name}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name    = "${var.project_name}-cloudwatch-agent-role"
    Project = var.project_name
  }
}

############################################
# CloudWatch Agent
#
# Preserves Version 1 CloudWatch
# Agent functionality.
############################################

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

############################################
# AWS Systems Manager
#
# Allows private EC2 managers/workers
# to register with Systems Manager and
# use Session Manager instead of SSH.
############################################

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

############################################
# Docker Swarm Parameter Store
#
# Used by manager_bootstrap.sh to:
#
#   - Determine the bootstrap manager
#   - Store/retrieve manager private IP
#   - Store/retrieve manager join token
#   - Store/retrieve worker join token
#
# Join tokens are stored as SecureString.
############################################

resource "aws_iam_role_policy" "docker_swarm_parameter_store" {
  name = "${var.project_name}-docker-swarm-parameter-store"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DockerSwarmParameterStore"
        Effect = "Allow"

        Action = [
          "ssm:DescribeParameters",
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]

        Resource = [
          "arn:aws:ssm:${var.aws_region}:*:parameter/engineering-for-failure/docker-swarm/*"
        ]
      }
    ]
  })
}

############################################
# KMS Decrypt Permission
#
# Required when retrieving Docker Swarm
# SecureString parameters from SSM.
#
# The policy is restricted to KMS requests
# made through the SSM service in this region.
############################################

resource "aws_iam_role_policy" "docker_swarm_parameter_store_kms" {
  name = "${var.project_name}-docker-swarm-kms"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "DockerSwarmSecureStringDecrypt"
        Effect = "Allow"

        Action = [
          "kms:Decrypt"
        ]

        Resource = "*"

        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

############################################
# EC2 Instance Profile
#
# Managers and workers will receive this
# profile so they can use:
#
#   - CloudWatch Agent
#   - SSM Session Manager
#   - SSM Parameter Store
############################################

resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "${var.project_name}-cloudwatch-agent-profile"
  role = aws_iam_role.cloudwatch_agent_role.name

  tags = {
    Name    = "${var.project_name}-cloudwatch-agent-profile"
    Project = var.project_name
  }
}

############################################
# Additional CloudWatch Permissions
#
# Preserves the existing Version 1
# dashboard, alarm, and log permissions.
############################################

resource "aws_iam_role_policy" "cloudwatch_dashboard_policy" {
  name = "${var.project_name}-cloudwatch-dashboard-policy"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "cloudwatch:GetDashboard",
          "cloudwatch:PutDashboard",
          "cloudwatch:ListDashboards",
          "cloudwatch:DeleteDashboards",

          "cloudwatch:DescribeAlarms",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",

          "logs:DescribeLogGroups",
          "logs:DescribeMetricFilters",
          "logs:PutMetricFilter"
        ]

        Resource = "*"
      }
    ]
  })
}