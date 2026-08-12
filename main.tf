terraform {
  required_version = ">= 1.5.0"
}

############################
# Data Sources
############################

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

############################
# VPC
############################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "docker-swarm-vpc"
    Project = var.project_name
  }
}

############################
# Internet Gateway
############################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "docker-swarm-igw"
    Project = var.project_name
  }
}

############################
# Public Subnets
#
# These will eventually host the
# internet-facing Application Load
# Balancer.
############################

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-a"
    Tier    = "public"
    AZ      = var.availability_zone_a
    Project = var.project_name
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-b"
    Tier    = "public"
    AZ      = var.availability_zone_b
    Project = var.project_name
  }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_c
  availability_zone       = var.availability_zone_c
  map_public_ip_on_launch = true

  tags = {
    Name    = "public-subnet-c"
    Tier    = "public"
    AZ      = var.availability_zone_c
    Project = var.project_name
  }
}

############################
# Private Subnets
#
# Docker Swarm managers and
# workers will use these subnets.
############################

resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_a
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = {
    Name    = "private-subnet-a"
    Tier    = "private"
    AZ      = var.availability_zone_a
    Project = var.project_name
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_b
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false

  tags = {
    Name    = "private-subnet-b"
    Tier    = "private"
    AZ      = var.availability_zone_b
    Project = var.project_name
  }
}

resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_c
  availability_zone       = var.availability_zone_c
  map_public_ip_on_launch = false

  tags = {
    Name    = "private-subnet-c"
    Tier    = "private"
    AZ      = var.availability_zone_c
    Project = var.project_name
  }
}

############################
# Public Route Table
############################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "public-route-table"
    Tier    = "public"
    Project = var.project_name
  }
}

############################
# Public Route Table Associations
############################

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

############################
# NAT Gateway Elastic IP
############################

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = {
    Name    = "docker-swarm-nat-eip"
    Project = var.project_name
  }
}

############################
# NAT Gateway
#
# Cost-optimized Version 2 design:
# one NAT Gateway in Public Subnet A.
############################

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name    = "docker-swarm-nat-gateway"
    Project = var.project_name
  }
}

############################
# Private Route Table
############################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name    = "private-route-table"
    Tier    = "private"
    Project = var.project_name
  }
}

############################
# Private Route Table Associations
############################

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_c" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

############################
# ALB Security Group
#
# The ALB will be introduced in
# the next networking step.
#
# It is created now so the
# security architecture is ready.
############################

resource "aws_security_group" "alb" {
  name        = "docker-swarm-alb-sg"
  description = "Security group for the internet-facing Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "docker-swarm-alb-sg"
    Project = var.project_name
  }
}

############################
# Docker Swarm Security Group
#
# Managers and workers communicate
# using the Docker Swarm ports.
#
# SSH is intentionally removed.
#
# HTTP remains available temporarily
# because the existing workers have
# not yet been moved behind the ALB.
############################

resource "aws_security_group" "docker_swarm" {
  name        = "docker-swarm-sg"
  description = "Docker Swarm node security group"
  vpc_id      = aws_vpc.main.id

  ############################
  # Docker Swarm management
  ############################

  ingress {
    description = "Docker Swarm cluster management"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ############################
  # Docker Swarm node communication
  ############################

  ingress {
    description = "Docker Swarm node communication TCP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Docker Swarm node communication UDP"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ############################
  # Docker overlay network
  ############################

  ingress {
    description = "Docker Swarm overlay network"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ############################
  # Temporary HTTP access
  #
  # This remains temporarily because
  # Worker1 and Worker2 are still
  # public in this phase.
  #
  # It will be removed/restricted
  # when the ALB becomes active.
  ############################

  ingress {
    description = "Temporary HTTP access for existing application workers"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ############################
  # Outbound
  ############################

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "docker-swarm-sg"
    Project = var.project_name
  }
}

############################
# Docker Swarm Managers
#
# Version 2:
#
# Manager 1 -> Private AZ-1
# Manager 2 -> Private AZ-2
# Manager 3 -> Private AZ-3
#
# No public IP addresses.
#
# IMPORTANT:
# The manager bootstrap script must
# be updated before applying this
# change because these instances
# will be replaced when their
# subnet changes.
############################

locals {
  managers = {
    Manager1 = {
      subnet = aws_subnet.private_a.id
      az     = var.availability_zone_a
    }

    Manager2 = {
      subnet = aws_subnet.private_b.id
      az     = var.availability_zone_b
    }

    Manager3 = {
      subnet = aws_subnet.private_c.id
      az     = var.availability_zone_c
    }
  }

  workers = {
    Worker1 = {
      subnet = aws_subnet.public_a.id
    }

    Worker2 = {
      subnet = aws_subnet.public_b.id
    }
  }
}

############################
# Manager EC2 Instances
############################

resource "aws_instance" "managers" {
  for_each = local.managers

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = each.value.subnet
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.docker_swarm.id]

  iam_instance_profile = aws_iam_instance_profile.manager_control_plane_profile.name

  associate_public_ip_address = false

  user_data = file("${path.module}/manager_bootstrap.sh")

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  tags = {
    Name    = each.key
    Role    = "Manager"
    AZ      = each.value.az
    Project = "Engineering-for-Failure-Docker-Swarm"
  }
}

############################
# Existing Workers
#
# These remain temporarily in
# their existing public subnets.
#
# They will be replaced by a
# 3-node Auto Scaling Group later.
############################

resource "aws_instance" "workers" {
  for_each = local.workers

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.docker_swarm.id]
  iam_instance_profile        = aws_iam_instance_profile.worker_runtime_profile.name
  associate_public_ip_address = true

  user_data = file("${path.module}/docker_install.sh")

  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  lifecycle {
    ignore_changes = [
      ami
    ]
  }

  tags = {
    Name    = each.key
    Role    = "Worker"
    Project = "Engineering-for-Failure-Docker-Swarm"
  }
}

############################
# CloudWatch Dashboard
#
# Retained temporarily.
# We will move this into
# dashboard.tf during the
# monitoring phase.
############################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = var.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "CPU Utilization"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            for i in merge(
              aws_instance.managers,
              aws_instance.workers
            ) :
            ["AWS/EC2", "CPUUtilization", "InstanceId", i.id]
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
          title  = "Status Checks"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            for i in merge(
              aws_instance.managers,
              aws_instance.workers
            ) :
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", i.id]
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
          title  = "Network In"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            for i in merge(
              aws_instance.managers,
              aws_instance.workers
            ) :
            ["AWS/EC2", "NetworkIn", "InstanceId", i.id]
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
          title  = "Network Out"
          view   = "timeSeries"
          region = var.aws_region

          metrics = [
            for i in merge(
              aws_instance.managers,
              aws_instance.workers
            ) :
            ["AWS/EC2", "NetworkOut", "InstanceId", i.id]
          ]
        }
      }
    ]
  })
}