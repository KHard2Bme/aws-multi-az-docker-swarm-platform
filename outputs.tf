output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_a_id" {
  description = "Public Subnet A ID"
  value       = aws_subnet.public_a.id
}

output "public_subnet_b_id" {
  description = "Public Subnet B ID"
  value       = aws_subnet.public_b.id
}

output "security_group_id" {
  description = "Docker Swarm Security Group ID"
  value       = aws_security_group.docker_swarm.id
}

output "instance_ids" {
  description = "EC2 Instance IDs"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.id
  }
}

output "public_ips" {
  description = "Public IP addresses"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.public_ip
  }
}

output "public_dns" {
  description = "Public DNS names"
  value = {
    for name, instance in aws_instance.nodes :
    name => instance.public_dns
  }
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch Dashboard"
  value       = aws_cloudwatch_dashboard.dashboard.dashboard_name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.docker_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN"
  value       = aws_cloudwatch_log_group.docker_logs.arn
}

output "cloudwatch_iam_role_name" {
  description = "IAM Role used by the CloudWatch Agent"
  value       = aws_iam_role.cloudwatch_agent_role.name
}

output "cloudwatch_instance_profile_name" {
  description = "IAM Instance Profile for EC2"
  value       = aws_iam_instance_profile.cloudwatch_agent_profile.name
}

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
