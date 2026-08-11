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
# Networking
############################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "docker-swarm-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "docker-swarm-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

############################
# Security Group
############################

resource "aws_security_group" "docker_swarm" {
  name        = "docker-swarm-sg"
  description = "Docker Swarm Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker-swarm-sg"
  }
}

############################
# EC2 Instances
############################

locals {
  instances = {
    Manager1 = { subnet = aws_subnet.public_a.id }
    Manager2 = { subnet = aws_subnet.public_a.id }
    Manager3 = { subnet = aws_subnet.public_b.id }
    Worker1  = { subnet = aws_subnet.public_a.id }
    Worker2  = { subnet = aws_subnet.public_b.id }
  }
}

resource "aws_instance" "nodes" {
  for_each = local.instances

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = each.value.subnet
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.docker_swarm.id]
  associate_public_ip_address = true
  user_data                   = file("${path.module}/docker_install.sh")
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
    Role    = startswith(each.key, "Manager") ? "Manager" : "Worker"
    Project = "Engineering-for-Failure-Docker-Swarm"
  }
}

############################
# CloudWatch Dashboard
############################

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = "EngineeringForFailureDashboard"

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
          region = "us-east-1"
          metrics = [
            for i in aws_instance.nodes :
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
          region = "us-east-1"
          metrics = [
            for i in aws_instance.nodes :
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
          region = "us-east-1"
          metrics = [
            for i in aws_instance.nodes :
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
          region = "us-east-1"
          metrics = [
            for i in aws_instance.nodes :
            ["AWS/EC2", "NetworkOut", "InstanceId", i.id]
          ]
        }
      }
    ]
  })
}