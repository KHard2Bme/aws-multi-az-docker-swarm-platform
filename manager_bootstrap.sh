#!/bin/bash

###############################################################################
# manager_bootstrap.sh
#
# Engineering for Failure
# Version 2 - Production-Ready Self-Healing Container Platform
#
# Purpose:
#   1. Install and start Docker
#   2. Ensure AWS Systems Manager Agent is running
#   3. Establish the initial Docker Swarm manager
#   4. Allow additional managers to automatically join
#   5. Store Swarm join information in SSM Parameter Store
#   6. Apply manager node labels
#   7. Drain managers so they do not run application containers
#
# All three managers use this same script.
###############################################################################

set -euo pipefail

###############################################################################
# Configuration
###############################################################################

AWS_REGION="us-east-1"

PARAMETER_PREFIX="/engineering-for-failure/docker-swarm"

BOOTSTRAP_PARAMETER="${PARAMETER_PREFIX}/bootstrap-manager"
MANAGER_IP_PARAMETER="${PARAMETER_PREFIX}/manager-ip"
MANAGER_TOKEN_PARAMETER="${PARAMETER_PREFIX}/manager-join-token"
WORKER_TOKEN_PARAMETER="${PARAMETER_PREFIX}/worker-join-token"

LOG_FILE="/var/log/manager-bootstrap.log"

###############################################################################
# Logging
###############################################################################

exec > >(tee -a "${LOG_FILE}") 2>&1

echo "============================================================"
echo "Docker Swarm Manager Bootstrap"
echo "Started: $(date)"
echo "============================================================"

###############################################################################
# Helper Functions
###############################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

###############################################################################
# Determine Instance Metadata
###############################################################################

TOKEN=$(curl -sX PUT \
    "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s \
    -H "X-aws-ec2-metadata-token: ${TOKEN}" \
    http://169.254.169.254/latest/meta-data/instance-id)

PRIVATE_IP=$(curl -s \
    -H "X-aws-ec2-metadata-token: ${TOKEN}" \
    http://169.254.169.254/latest/meta-data/local-ipv4)

REGION=$(curl -s \
    -H "X-aws-ec2-metadata-token: ${TOKEN}" \
    http://169.254.169.254/latest/meta-data/placement/region)

AWS_REGION="${REGION:-${AWS_REGION}}"

log "Instance ID: ${INSTANCE_ID}"
log "Private IP: ${PRIVATE_IP}"
log "AWS Region: ${AWS_REGION}"

###############################################################################
# Install Required Packages
###############################################################################

log "Updating Amazon Linux packages..."

dnf update -y

log "Installing Docker and AWS CLI..."

dnf install -y docker awscli

###############################################################################
# Start Docker
###############################################################################

log "Enabling Docker..."

systemctl enable docker

log "Starting Docker..."

systemctl start docker

sleep 5

if ! systemctl is-active --quiet docker; then
    log "ERROR: Docker failed to start."
    exit 1
fi

log "Docker is running."

###############################################################################
# Ensure ec2-user can use Docker
###############################################################################

if id ec2-user >/dev/null 2>&1; then
    usermod -aG docker ec2-user
fi

###############################################################################
# Ensure SSM Agent Is Running
###############################################################################

log "Checking AWS Systems Manager Agent..."

if systemctl list-unit-files | grep -q amazon-ssm-agent; then

    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    if systemctl is-active --quiet amazon-ssm-agent; then
        log "SSM Agent is running."
    else
        log "WARNING: SSM Agent did not start successfully."
    fi

else
    log "Installing AWS Systems Manager Agent..."

    dnf install -y amazon-ssm-agent

    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    if systemctl is-active --quiet amazon-ssm-agent; then
        log "SSM Agent installed and running."
    else
        log "WARNING: SSM Agent failed to start."
    fi

fi

###############################################################################
# Verify AWS CLI
###############################################################################

if ! command -v aws >/dev/null 2>&1; then
    log "ERROR: AWS CLI is not available."
    exit 1
fi

log "AWS CLI is available."

###############################################################################
# Wait for SSM Parameter Store Access
#
# The IAM instance profile will be added through Terraform.
# We wait until the instance can communicate with Parameter Store.
###############################################################################

log "Waiting for SSM Parameter Store access..."

SSM_READY=false

for attempt in {1..30}; do

    if aws ssm describe-parameters \
        --region "${AWS_REGION}" \
        --max-results 1 >/dev/null 2>&1; then

        SSM_READY=true
        log "SSM Parameter Store is accessible."
        break
    fi

    log "SSM Parameter Store not ready. Attempt ${attempt}/30."
    sleep 10

done

if [ "${SSM_READY}" != "true" ]; then
    log "ERROR: Unable to access SSM Parameter Store."
    exit 1
fi

###############################################################################
# Swarm Bootstrap Coordination
#
# The first manager to successfully create BOOTSTRAP_PARAMETER becomes
# the initial Swarm manager.
#
# The parameter is created WITHOUT overwrite.
# This provides a simple bootstrap election mechanism.
###############################################################################

log "Attempting to determine the initial Swarm manager..."

IS_BOOTSTRAP_MANAGER=false

if aws ssm put-parameter \
    --name "${BOOTSTRAP_PARAMETER}" \
    --value "${INSTANCE_ID}" \
    --type "String" \
    --region "${AWS_REGION}" \
    --description "Initial Docker Swarm manager instance" \
    >/dev/null 2>&1; then

    IS_BOOTSTRAP_MANAGER=true

    log "This instance won the Swarm bootstrap election."
    log "Initial manager instance: ${INSTANCE_ID}"

else

    log "Another manager has already claimed Swarm bootstrap."
    log "This instance will wait for the Swarm join information."

fi

###############################################################################
# Initial Manager
###############################################################################

if [ "${IS_BOOTSTRAP_MANAGER}" = "true" ]; then

    log "Checking whether Docker Swarm is already initialized..."

    if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "^active$"; then

        log "Docker Swarm is already active on this manager."

    else

        log "Initializing Docker Swarm..."

        docker swarm init \
            --advertise-addr "${PRIVATE_IP}"

        log "Docker Swarm initialized successfully."

    fi

    ###########################################################################
    # Store Manager IP
    ###########################################################################

    log "Storing Swarm manager private IP in Parameter Store..."

    aws ssm put-parameter \
        --name "${MANAGER_IP_PARAMETER}" \
        --value "${PRIVATE_IP}" \
        --type "String" \
        --overwrite \
        --region "${AWS_REGION}"

    ###########################################################################
    # Obtain Manager Join Token
    ###########################################################################

    MANAGER_TOKEN=$(docker swarm join-token manager -q)

    log "Storing manager join token in Parameter Store..."

    aws ssm put-parameter \
        --name "${MANAGER_TOKEN_PARAMETER}" \
        --value "${MANAGER_TOKEN}" \
        --type "SecureString" \
        --overwrite \
        --region "${AWS_REGION}"

    ###########################################################################
    # Obtain Worker Join Token
    ###########################################################################

    WORKER_TOKEN=$(docker swarm join-token worker -q)

    log "Storing worker join token in Parameter Store..."

    aws ssm put-parameter \
        --name "${WORKER_TOKEN_PARAMETER}" \
        --value "${WORKER_TOKEN}" \
        --type "SecureString" \
        --overwrite \
        --region "${AWS_REGION}"

    log "Swarm join information stored successfully."

###############################################################################
# Additional Managers
###############################################################################

else

    log "Waiting for the initial Swarm manager to publish join information..."

    MANAGER_READY=false

    for attempt in {1..60}; do

        if aws ssm get-parameter \
            --name "${MANAGER_IP_PARAMETER}" \
            --region "${AWS_REGION}" \
            >/dev/null 2>&1 && \
           aws ssm get-parameter \
            --name "${MANAGER_TOKEN_PARAMETER}" \
            --with-decryption \
            --region "${AWS_REGION}" \
            >/dev/null 2>&1; then

            MANAGER_READY=true
            log "Swarm manager join information is available."
            break
        fi

        log "Waiting for Swarm manager. Attempt ${attempt}/60."
        sleep 10

    done

    if [ "${MANAGER_READY}" != "true" ]; then
        log "ERROR: Swarm manager join information was not available."
        exit 1
    fi

    ###########################################################################
    # Retrieve Manager Information
    ###########################################################################

    MANAGER_IP=$(aws ssm get-parameter \
        --name "${MANAGER_IP_PARAMETER}" \
        --region "${AWS_REGION}" \
        --query "Parameter.Value" \
        --output text)

    MANAGER_TOKEN=$(aws ssm get-parameter \
        --name "${MANAGER_TOKEN_PARAMETER}" \
        --with-decryption \
        --region "${AWS_REGION}" \
        --query "Parameter.Value" \
        --output text)

    log "Joining existing Swarm as a manager..."

    if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "^active$"; then

        log "This node is already part of a Docker Swarm."

    else

        docker swarm join \
            --token "${MANAGER_TOKEN}" \
            "${MANAGER_IP}:2377"

        log "Successfully joined the Docker Swarm as a manager."

    fi

fi

###############################################################################
# Determine Local Swarm Node ID
###############################################################################

log "Waiting for Docker Swarm node information..."

NODE_ID=""

for attempt in {1..30}; do

    NODE_ID=$(docker info \
        --format '{{.Swarm.NodeID}}' 2>/dev/null || true)

    if [ -n "${NODE_ID}" ] && [ "${NODE_ID}" != "<no value>" ]; then
        break
    fi

    sleep 5

done

if [ -z "${NODE_ID}" ] || [ "${NODE_ID}" = "<no value>" ]; then
    log "ERROR: Unable to determine Docker Swarm node ID."
    exit 1
fi

log "Local Swarm node ID: ${NODE_ID}"

###############################################################################
# Determine Local Node Hostname
###############################################################################

NODE_HOSTNAME=$(hostname)

log "Local hostname: ${NODE_HOSTNAME}"

###############################################################################
# Apply Manager Labels
#
# These labels provide explicit workload separation.
###############################################################################

log "Applying manager node labels..."

docker node update \
    --label-add role=manager \
    --label-add workload=control-plane \
    --label-add apache=false \
    "${NODE_ID}"

log "Manager labels applied."

###############################################################################
# Drain Manager
#
# Managers should provide the Docker Swarm control plane and should not
# receive application containers.
###############################################################################

log "Setting manager availability to drain..."

docker node update \
    --availability drain \
    "${NODE_ID}"

log "Manager is now drained."

###############################################################################
# Display Final Node Configuration
###############################################################################

log "Final Docker Swarm node configuration:"

docker node inspect "${NODE_ID}" \
    --pretty || true

###############################################################################
# Bootstrap Complete
###############################################################################

echo "============================================================"
echo "Docker Swarm Manager Bootstrap Complete"
echo "Instance: ${INSTANCE_ID}"
echo "Private IP: ${PRIVATE_IP}"
echo "Role: Manager"
echo "Workload: Control Plane"
echo "Availability: Drain"
echo "Completed: $(date)"
echo "============================================================"

exit 0