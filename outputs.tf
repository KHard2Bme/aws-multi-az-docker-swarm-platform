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
############################

output "manager_instance_ids" {
  description = "EC2 Instance IDs for the Docker Swarm managers"
  value = {
    for name, instance in aws_instance.managers :
    name => instance.id
  }
}

output "manager_private_ips" {
  description = "Private IP addresses of the Docker Swarm managers"
  value = {
    for name, instance in aws_instance.managers :
    name => instance.private_ip
  }
}

output "manager_private_dns" {
  description = "Private DNS names of the Docker Swarm managers"
  value = {
    for name, instance in aws_instance.managers :
    name => instance.private_dns
  }
}

output "worker_instance_ids" {
  description = "Worker Auto Scaling Group names"

  value = {
    AZ_A = aws_autoscaling_group.workers_a.name
    AZ_B = aws_autoscaling_group.workers_b.name
    AZ_C = aws_autoscaling_group.workers_c.name
  }
}

output "worker_public_ips" {
  description = "Worker public IP addresses - workers are deployed in private subnets"

  value = "Workers are private and do not have public IP addresses."
}

output "worker_public_dns" {
  description = "Worker public DNS names - workers are deployed in private subnets"

  value = "Workers are private and do not have public DNS names."
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

output "manager_control_plane_role_name" {
  description = "IAM role used by Docker Swarm manager/control-plane nodes"
  value       = aws_iam_role.manager_control_plane_role.name
}

output "manager_control_plane_profile_name" {
  description = "IAM instance profile used by Docker Swarm manager/control-plane nodes"
  value       = aws_iam_instance_profile.manager_control_plane_profile.name
}

output "worker_runtime_profile_name" {
  description = "IAM instance profile used by Docker Swarm application worker nodes"
  value       = aws_iam_instance_profile.worker_runtime_profile.name
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

##################################################
# Application Load Balancer
##################################################

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.application.dns_name
}

output "alb_url" {
  description = "URL for the SkyBound Travel application"
  value       = "http://${aws_lb.application.dns_name}"
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.application.arn
}

output "apache_target_group_arn" {
  description = "ARN of the Apache Application Load Balancer target group"
  value       = aws_lb_target_group.apache.arn
}