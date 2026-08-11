############################################################
# variables.tf
# Engineering for Failure: Docker Swarm on AWS
############################################################

variable "aws_region" {
  description = "AWS Region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 Key Pair"
  type        = string
}

variable "my_ip" {
  description = "Public IPv4 in CIDR notation (example: 203.0.113.10/32)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a" {
  description = "Public Subnet A CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b" {
  description = "Public Subnet B CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone_a" {
  description = "Availability Zone A"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_b" {
  description = "Availability Zone B"
  type        = string
  default     = "us-east-1b"
}

variable "dashboard_name" {
  description = "CloudWatch Dashboard Name"
  type        = string
  default     = "EngineeringForFailureDashboard"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "engineering-for-failure"
}