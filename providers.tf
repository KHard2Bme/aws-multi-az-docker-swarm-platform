############################################################
# providers.tf
# Engineering for Failure: Docker Swarm on AWS
# Author: Kevin Harding
############################################################

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################################################
# AWS Provider
############################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Engineering-for-Failure-Docker-Swarm"
      Environment = "Lab"
      Owner       = "Kevin Harding"
      ManagedBy   = "Terraform"
    }
  }
}
