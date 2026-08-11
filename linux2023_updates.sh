#!/bin/bash

#########################################################
# Amazon Linux 2023 System Update Script
# Author: Kevin Harding
# Description:
# Updates Amazon Linux 2023 packages and installs Apache
#########################################################

set -euxo pipefail

echo "======================================"
echo "Updating package repository..."
echo "======================================"

sudo dnf update -y

echo "======================================"
echo "Installing Apache (httpd)..."
echo "======================================"

sudo dnf install -y httpd

echo "======================================"
echo "Enabling Apache..."
echo "======================================"

sudo systemctl enable httpd

echo "======================================"
echo "Starting Apache..."
echo "======================================"

sudo systemctl start httpd

echo "======================================"
echo "Verifying Apache Service..."
echo "======================================"

sudo systemctl --no-pager --full status httpd

echo "======================================"
echo "Apache Version"
echo "======================================"

httpd -v

echo "======================================"
echo "Operating System"
echo "======================================"

cat /etc/os-release

echo "======================================"
echo "Installed Packages"
echo "======================================"

rpm -q httpd

echo "======================================"
echo "System update completed successfully!"
echo "======================================"