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
}

  ##################################################
  # Application Load Balancer
  #
  # Internet-facing ALB deployed across
  # the three public subnets.
  ##################################################

  resource "aws_lb" "application" {
    name               = "${var.project_name}-alb"
    internal           = false
    load_balancer_type = "application"

    security_groups = [
      aws_security_group.alb.id
    ]

    subnets = [
      aws_subnet.public_a.id,
      aws_subnet.public_b.id,
      aws_subnet.public_c.id
    ]

    enable_deletion_protection = false

    tags = {
      Name    = "${var.project_name}-alb"
      Project = var.project_name
      Role    = "Application Load Balancer"
    }
  }


  ##################################################
  # ALB Target Group
  #
  # The ALB forwards traffic to the
  # Docker Swarm worker nodes on port 80.
  #
  # Docker Swarm's routing mesh allows
  # traffic arriving at a worker to reach
  # the Apache service.
  ##################################################

  resource "aws_lb_target_group" "apache" {
    name        = "${var.project_name}-apache-tg"
    port        = 80
    protocol    = "HTTP"
    target_type = "instance"

    vpc_id = aws_vpc.main.id

    health_check {
      enabled             = true
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
      interval            = 30

      protocol = "HTTP"
      path     = "/"

      matcher = "200"
    }

    tags = {
      Name    = "${var.project_name}-apache-tg"
      Project = var.project_name
      Service = "Apache"
    }
  }


  ##################################################
  # ALB Listener
  ##################################################

  resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.application.arn

    port     = 80
    protocol = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.apache.arn
    }
  }


  ############################
  # HTTP from Application Load Balancer
  #
  # Workers remain private.
  # Application traffic is allowed
  # only from the ALB security group.
  ############################

  ingress {
    description     = "HTTP from Application Load Balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
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

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }


  tags = {
    Name    = each.key
    Role    = "Manager"
    AZ      = each.value.az
    Project = "Engineering-for-Failure-Docker-Swarm"
  }
}

############################
# Worker Launch Template
#
# Application/runtime nodes.
#
# Workers:
# - use the worker runtime IAM profile
# - run in private subnets
# - install Docker
# - install SSM Agent
# - retrieve the Swarm worker token
# - join the Swarm as workers
############################

resource "aws_launch_template" "workers" {

  name_prefix = "${var.project_name}-worker-"

  image_id = data.aws_ami.amazon_linux.id

  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_runtime_profile.name
  }

  vpc_security_group_ids = [
    aws_security_group.docker_swarm.id
  ]

  user_data = filebase64("${path.module}/worker_bootstrap.sh")

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Role    = "Worker"
      Project = "Engineering-for-Failure-Docker-Swarm"
      Managed = "Terraform-ASG"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Role    = "Worker"
      Project = "Engineering-for-Failure-Docker-Swarm"
    }
  }
}

############################
# Worker ASG - AZ A
############################

resource "aws_autoscaling_group" "workers_a" {

  name = "${var.project_name}-workers-a"

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  target_group_arns = [
    aws_lb_target_group.apache.arn
  ]

  vpc_zone_identifier = [
    aws_subnet.private_a.id
  ]

  launch_template {
    id      = aws_launch_template.workers.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  depends_on = [
    aws_iam_instance_profile.worker_runtime_profile
  ]

  tag {
    key                 = "Name"
    value               = "Worker-A"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "AZ"
    value               = var.availability_zone_a
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Engineering-for-Failure-Docker-Swarm"
    propagate_at_launch = true
  }
}


############################
# Worker ASG - AZ B
############################

resource "aws_autoscaling_group" "workers_b" {

  name = "${var.project_name}-workers-b"

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  target_group_arns = [
    aws_lb_target_group.apache.arn
  ]

  vpc_zone_identifier = [
    aws_subnet.private_b.id
  ]

  launch_template {
    id      = aws_launch_template.workers.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  depends_on = [
    aws_iam_instance_profile.worker_runtime_profile
  ]

  tag {
    key                 = "Name"
    value               = "Worker-B"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "AZ"
    value               = var.availability_zone_b
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Engineering-for-Failure-Docker-Swarm"
    propagate_at_launch = true
  }
}


############################
# Worker ASG - AZ C
############################

resource "aws_autoscaling_group" "workers_c" {

  name = "${var.project_name}-workers-c"

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  target_group_arns = [
    aws_lb_target_group.apache.arn
  ]

  vpc_zone_identifier = [
    aws_subnet.private_c.id
  ]

  launch_template {
    id      = aws_launch_template.workers.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  depends_on = [
    aws_iam_instance_profile.worker_runtime_profile
  ]

  tag {
    key                 = "Name"
    value               = "Worker-C"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "Worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "AZ"
    value               = var.availability_zone_c
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Engineering-for-Failure-Docker-Swarm"
    propagate_at_launch = true
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
            for i in aws_instance.managers :
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
            for i in aws_instance.managers :
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
            for i in aws_instance.managers :
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
            for i in aws_instance.managers :
            ["AWS/EC2", "NetworkOut", "InstanceId", i.id]
          ]
        }
      }
    ]
  })
}