#!/bin/bash

#########################################################
# Docker Installation Script
# Author: Kevin Harding
# Description:
# Installs and configures Docker on Amazon Linux 2023.
# Executed automatically by Terraform using EC2 user_data.
#########################################################

# Exit immediately if a command fails.
set -e

# Update all installed system packages.
dnf update -y

# Install the Docker engine from the Amazon Linux 2023 repository.
dnf install docker -y

# Configure Docker to start automatically whenever the instance boots.
systemctl enable docker

# Start the Docker service immediately.
systemctl start docker

# Add the default EC2 user to the Docker group.
# This allows Docker commands to be run without sudo
# after the user signs out and signs back in.
usermod -aG docker ec2-user

