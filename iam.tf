############################################################
# iam.tf
# Engineering for Failure - Version 2
#
# IAM Architecture
#
# MANAGER / CONTROL-PLANE
#   - SSM Session Manager
#   - Docker Swarm bootstrap
#   - Scoped SSM Parameter Store access
#   - CloudWatch Agent telemetry
#
# WORKER / APPLICATION RUNTIME
#   - CloudWatch telemetry only
#   - No Swarm token access
#   - No Parameter Store administration
#   - No CloudWatch dashboard/alarm administration
#
############################################################


############################################################
# MANAGER / CONTROL-PLANE IAM
############################################################

############################
# Manager Assume Role Policy
############################

data "aws_iam_policy_document" "manager_assume_role" {

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}


############################
# Manager IAM Role
############################

resource "aws_iam_role" "manager_control_plane_role" {

  name = "${var.project_name}-manager-control-plane-role"

  assume_role_policy = data.aws_iam_policy_document.manager_assume_role.json

  tags = {
    Name    = "${var.project_name}-manager-control-plane-role"
    Project = var.project_name
    Role    = "Manager-Control-Plane"
  }
}


############################
# Systems Manager
#
# Allows private managers to:
#
#   - Register with SSM
#   - Use Session Manager
#   - Receive SSM commands
#
# This replaces SSH as the primary
# administrative access mechanism.
############################

resource "aws_iam_role_policy_attachment" "manager_ssm" {

  role = aws_iam_role.manager_control_plane_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


############################
# CloudWatch Agent
#
# Managers publish infrastructure
# telemetry to CloudWatch.
############################

resource "aws_iam_role_policy_attachment" "manager_cloudwatch_agent" {

  role = aws_iam_role.manager_control_plane_role.name

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


############################
# Docker Swarm Parameter Store
#
# Managers require access to:
#
#   /engineering-for-failure/docker-swarm/*
#
# This is used by manager_bootstrap.sh
# for:
#
#   - Bootstrap coordination
#   - Manager private IP
#   - Manager join token
#   - Worker join token
############################

resource "aws_iam_role_policy" "manager_swarm_parameter_store" {

  name = "${var.project_name}-manager-swarm-parameter-store"

  role = aws_iam_role.manager_control_plane_role.id

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


############################
# KMS Decrypt
#
# Required for retrieving the
# SecureString Swarm join tokens.
#
# Access is restricted to requests
# made through SSM in this region.
############################

resource "aws_iam_role_policy" "manager_swarm_kms" {

  name = "${var.project_name}-manager-swarm-kms"

  role = aws_iam_role.manager_control_plane_role.id

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Sid    = "DecryptSwarmSecureStrings"

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


############################
# Manager Instance Profile
############################

resource "aws_iam_instance_profile" "manager_control_plane_profile" {

  name = "${var.project_name}-manager-control-plane-profile"

  role = aws_iam_role.manager_control_plane_role.name

  tags = {
    Name    = "${var.project_name}-manager-control-plane-profile"
    Project = var.project_name
    Role    = "Manager-Control-Plane"
  }
}



############################################################
# WORKER / APPLICATION RUNTIME IAM
############################################################

############################
# Worker Assume Role Policy
############################

data "aws_iam_policy_document" "worker_assume_role" {

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}


############################
# Worker Runtime IAM Role
############################

resource "aws_iam_role" "worker_runtime_role" {

  name = "${var.project_name}-worker-runtime-role"

  assume_role_policy = data.aws_iam_policy_document.worker_assume_role.json

  tags = {
    Name    = "${var.project_name}-worker-runtime-role"
    Project = var.project_name
    Role    = "Worker-Application-Runtime"
  }
}


############################
# Worker CloudWatch Telemetry
#
# Allows the worker/application
# node to publish telemetry.
#
# It does NOT provide:
#
#   - Parameter Store access
#   - Swarm token access
#   - Dashboard administration
#   - Alarm administration
#   - IAM administration
############################

resource "aws_iam_role_policy_attachment" "worker_cloudwatch_agent" {

  role = aws_iam_role.worker_runtime_role.name

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


############################
# Worker Instance Profile
############################

resource "aws_iam_instance_profile" "worker_runtime_profile" {

  name = "${var.project_name}-worker-runtime-profile"

  role = aws_iam_role.worker_runtime_role.name

  tags = {
    Name    = "${var.project_name}-worker-runtime-profile"
    Project = var.project_name
    Role    = "Worker-Application-Runtime"
  }
}