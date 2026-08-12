############################################################
# outputs.tf
# Engineering for Failure: Docker Swarm on AWS - Version 2
############################################################

############################
# VPC
############################

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

############################
# Availability Zones
############################

output "availability_zones" {
  description = "Availability Zones used by the Version 2 network"
  value = [
    var.availability_zone_a,
    var.availability_zone_b,
    var.availability_zone_c
  ]
}

############################
# Public Subnets
############################

output "public_subnet_a_id" {
  description = "Public Subnet A ID"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "Public Subnet B ID"
  value       = aws_subnet.public_b.id
}

output "public_subnet_c_id" {
  description = "Public Subnet C ID"
  value       = aws_subnet.public_c.id
}

output "public_subnet_ids" {
  description = "All public subnet IDs"
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
    aws_subnet.public_c.id
  ]
}

############################
# Private Subnets
############################

output "private_subnet_a_id" {
  description = "Private Subnet A ID"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "Private Subnet B ID"
  value       = aws_subnet.private_b.id
}

output "private_subnet_c_id" {
  description = "Private Subnet C ID"
  value       = aws_subnet.private_c.id
}

output "private_subnet_ids" {
  description = "All private subnet IDs"
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
}

############################
# NAT Gateway
############################

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Elastic IP address associated with the NAT Gateway"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

############################
# Route Tables
############################

output "public_route_table_id" {
  description = "Public Route Table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private Route Table ID"
  value       = aws_route_table.private.id
}

############################
# Security Group
############################

output "security_group_id" {
  description = "Docker Swarm Security Group ID"
  value       = aws_security_group.docker_swarm.id
}

############################
# EC2 Instances
#
# These outputs remain temporarily
# because the current Version 1-style
# EC2 resources are still present.
############################

output "instance_ids" {
  description = "EC2 Instance IDs"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.id
  }
}

output "public_ips" {
  description = "Public IP addresses of the current EC2 instances"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.public_ip
  }
}

output "public_dns" {
  description = "Public DNS names of the current EC2 instances"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.public_dns
  }
}

############################
# CloudWatch Dashboard
############################

output "cloudwatch_dashboard_name" {
  description = "CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.dashboard.dashboard_name
}

############################
# CloudWatch Logging
############################

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.docker_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.docker_logs.arn
}

############################
# CloudWatch IAM
############################

output "cloudwatch_iam_role_name" {
  description = "IAM Role used by the CloudWatch Agent"
  value       = aws_iam_role.cloudwatch_agent_role.name
}

output "cloudwatch_instance_profile_name" {
  description = "IAM Instance Profile for EC2"
  value       = aws_iam_instance_profile.cloudwatch_agent_profile.name
}

############################
# CloudWatch Metric Filters
############################

output "container_failure_metric" {
  description = "Container failure metric filter"
  value       = aws_cloudwatch_log_metric_filter.container_failure.name
}

output "worker_failure_metric" {
  description = "Worker node failure metric filter"
  value       = aws_cloudwatch_log_metric_filter.worker_node_failure.name
}

output "manager_failure_metric" {
  description = "Manager node failure metric filter"
  value       = aws_cloudwatch_log_metric_filter.manager_node_failure.name
}

