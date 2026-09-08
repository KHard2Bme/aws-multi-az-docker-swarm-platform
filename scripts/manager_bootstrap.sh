#!/bin/bash
set -u

LOG_FILE="/var/log/manager-bootstrap.log"
REGION="us-east-1"

PARAMETER_PATH="/engineering-for-failure/docker-swarm"
CLOUDWATCH_CONFIG_PARAMETER="/engineering-for-failure/cloudwatch/agent-config"

CLOUDWATCH_CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"

DOCKER_EVENT_MONITOR="/usr/local/bin/docker_event_monitor.sh"
DOCKER_EVENT_SERVICE="/etc/systemd/system/docker-event-monitor.service"

DOCKER_SERVICE_MONITOR="/usr/local/bin/docker_service_monitor.sh"
DOCKER_SERVICE_SERVICE="/etc/systemd/system/docker-service-monitor.service"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

log "Docker Swarm Manager Bootstrap Starting"

#############################################
# Determine Private IP Using IMDSv2
#############################################

PRIVATE_IP=""

log "Determining manager private IP address..."

for attempt in $(seq 1 12); do

  IMDS_TOKEN=$(curl -sS --max-time 5 \
    -X PUT \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
    http://169.254.169.254/latest/api/token 2>/dev/null || true)

  if [ -n "$IMDS_TOKEN" ]; then

    PRIVATE_IP=$(curl -sS --max-time 5 \
      -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
      http://169.254.169.254/latest/meta-data/local-ipv4 \
      2>/dev/null || true)

  fi

  if [ -n "$PRIVATE_IP" ]; then
    break
  fi

  log "Private IP not available yet. Attempt ${attempt}/12."
  sleep 5

done

[ -n "$PRIVATE_IP" ] || fail "Unable to determine private IP address."

log "Manager private IP: $PRIVATE_IP"

#############################################
# Docker Installation
#############################################

if ! command -v docker >/dev/null 2>&1; then

  log "Installing Docker..."

  dnf install -y docker || fail "Docker installation failed."

fi

systemctl enable docker

systemctl start docker || \
  fail "Unable to start Docker."

systemctl is-active --quiet docker || \
  fail "Docker service is not active."

log "Docker is running."

#############################################
# AWS Systems Manager Agent
#############################################

if ! systemctl list-unit-files | \
  grep -q '^amazon-ssm-agent.service'; then

  log "Installing AWS Systems Manager Agent..."

  dnf install -y amazon-ssm-agent || \
    fail "SSM Agent installation failed."

fi

systemctl enable amazon-ssm-agent

systemctl start amazon-ssm-agent || \
  fail "Unable to start SSM Agent."

systemctl is-active --quiet amazon-ssm-agent || \
  fail "SSM Agent is not active."

log "SSM Agent is running."

#############################################
# AWS CLI Validation
#############################################

command -v aws >/dev/null 2>&1 || \
  fail "AWS CLI is not available."

log "AWS CLI is available."

#############################################
# Wait For SSM Parameter Store Access
#############################################

log "Waiting for SSM Parameter Store access..."

SSM_READY=false

for attempt in $(seq 1 30); do

  if aws ssm get-parameter \
    --name "${PARAMETER_PATH}/manager-ip" \
    --region "$REGION" \
    >/dev/null 2>&1; then

    SSM_READY=true

    log "SSM Parameter Store is accessible."

    break

  fi

  log "SSM Parameter Store not ready. Attempt ${attempt}/30."

  sleep 10

done

[ "$SSM_READY" = true ] || \
  fail "Unable to access required SSM Parameter Store parameters."

#############################################
# Install CloudWatch Agent
#############################################

if ! command -v amazon-cloudwatch-agent-ctl \
  >/dev/null 2>&1; then

  log "Installing Amazon CloudWatch Agent..."

  dnf install -y amazon-cloudwatch-agent || \
    fail "CloudWatch Agent installation failed."

fi

log "Amazon CloudWatch Agent is installed."

#############################################
# Retrieve CloudWatch Agent Configuration
#############################################

log "Retrieving CloudWatch Agent configuration from SSM Parameter Store..."

mkdir -p "$(dirname "$CLOUDWATCH_CONFIG_FILE")"

CLOUDWATCH_CONFIG_READY=false

for attempt in $(seq 1 30); do

  if aws ssm get-parameter \
    --name "$CLOUDWATCH_CONFIG_PARAMETER" \
    --region "$REGION" \
    --query 'Parameter.Value' \
    --output text \
    > "$CLOUDWATCH_CONFIG_FILE" 2>/dev/null; then

    if [ -s "$CLOUDWATCH_CONFIG_FILE" ]; then

      CLOUDWATCH_CONFIG_READY=true

      log "CloudWatch Agent configuration retrieved successfully."

      break

    fi

  fi

  log "CloudWatch configuration not available yet. Attempt ${attempt}/30."

  sleep 10

done

[ "$CLOUDWATCH_CONFIG_READY" = true ] || \
  fail "Unable to retrieve CloudWatch Agent configuration."

#############################################
# Create Docker Event Monitor Script
#############################################

log "Creating Docker event monitoring script..."

cat > "$DOCKER_EVENT_MONITOR" <<'EOF'
#!/bin/bash

LOG_FILE="/var/log/docker-events.log"

touch "$LOG_FILE"

chmod 644 "$LOG_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DockerEventMonitorStarted" \
  >> "$LOG_FILE"

docker events \
  --filter 'event=die' \
  --filter 'event=stop' \
  --format '{{json .}}' |
while read -r event; do

  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  echo "[$timestamp] ContainerFailure $event" \
    >> "$LOG_FILE"

done
EOF

chmod 755 "$DOCKER_EVENT_MONITOR"

log "Docker event monitoring script created."

#############################################
# Create Docker Event Monitor Service
#############################################

log "Creating Docker event monitor systemd service..."

cat > "$DOCKER_EVENT_SERVICE" <<EOF
[Unit]
Description=Docker Event Monitoring Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=$DOCKER_EVENT_MONITOR
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable docker-event-monitor.service

systemctl restart docker-event-monitor.service || \
  fail "Unable to start Docker event monitoring service."

systemctl is-active --quiet docker-event-monitor.service || \
  fail "Docker event monitoring service is not active."

log "Docker event monitoring service is running."

#############################################
# Create Docker Service Failure Monitor Script
#############################################

log "Creating Docker service failure monitoring script..."

cat > "$DOCKER_SERVICE_MONITOR" <<'EOF'
#!/bin/bash
set -u
NODE_ROLE="$1"
LOG_FILE="/var/log/docker-events.log"

if [ "$NODE_ROLE" = "worker" ]; then
  FAILURE_EVENT="WorkerNodeFailure"
else
  FAILURE_EVENT="ManagerNodeFailure"
fi

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] DockerServiceMonitorStarted role=${NODE_ROLE}" >> "$LOG_FILE"

FAILURE_REPORTED=false
while true; do
  if ! systemctl is-active --quiet docker; then
    if [ "$FAILURE_REPORTED" = false ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${FAILURE_EVENT} docker_service=inactive role=${NODE_ROLE} hostname=$(hostname)" >> "$LOG_FILE"
      FAILURE_REPORTED=true
    fi
  else
    if [ "$FAILURE_REPORTED" = true ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] DockerServiceRecovered role=${NODE_ROLE} hostname=$(hostname)" >> "$LOG_FILE"
      FAILURE_REPORTED=false
    fi
  fi
  sleep 5
done
EOF

chmod 755 "$DOCKER_SERVICE_MONITOR"

cat > "$DOCKER_SERVICE_SERVICE" <<EOF
[Unit]
Description=Docker Service Failure Monitor
After=network.target

[Service]
Type=simple
ExecStart=$DOCKER_SERVICE_MONITOR manager
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-service-monitor.service
systemctl restart docker-service-monitor.service || \
  fail "Unable to start Docker service failure monitoring service."

systemctl is-active --quiet docker-service-monitor.service || \
  fail "Docker service failure monitoring service is not active."

log "Docker service failure monitoring service is running."

#############################################
# Start CloudWatch Agent
#############################################

log "Starting Amazon CloudWatch Agent..."

amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c "file:${CLOUDWATCH_CONFIG_FILE}" \
  || fail "Unable to start CloudWatch Agent."

systemctl is-active --quiet amazon-cloudwatch-agent || \
  fail "CloudWatch Agent is not active."

log "Amazon CloudWatch Agent is running."

#############################################
# Configure Docker Swarm Manager
#############################################

SWARM_STATE=$(docker info \
  --format '{{.Swarm.LocalNodeState}}' \
  2>/dev/null || true)

if [ "$SWARM_STATE" != "active" ]; then

  MANAGER_IP=$(aws ssm get-parameter \
    --name "${PARAMETER_PATH}/manager-ip" \
    --region "$REGION" \
    --query Parameter.Value \
    --output text 2>/dev/null || true)

  if [ -z "$MANAGER_IP" ] || [ "$MANAGER_IP" = "None" ]; then

    log "No existing manager found. Initializing first Swarm manager..."

    docker swarm init \
      --advertise-addr "$PRIVATE_IP" \
      || fail "Docker Swarm manager initialization failed."

    aws ssm put-parameter \
      --name "${PARAMETER_PATH}/manager-ip" \
      --type String \
      --value "$PRIVATE_IP" \
      --overwrite \
      --region "$REGION" >/dev/null || \
      fail "Unable to store manager IP."

    MANAGER_JOIN_TOKEN=$(docker swarm join-token -q manager) || \
      fail "Unable to retrieve manager join token."

    WORKER_JOIN_TOKEN=$(docker swarm join-token -q worker) || \
      fail "Unable to retrieve worker join token."

    aws ssm put-parameter \
      --name "${PARAMETER_PATH}/manager-join-token" \
      --type SecureString \
      --value "$MANAGER_JOIN_TOKEN" \
      --overwrite \
      --region "$REGION" >/dev/null || \
      fail "Unable to store manager join token."

    aws ssm put-parameter \
      --name "${PARAMETER_PATH}/worker-join-token" \
      --type SecureString \
      --value "$WORKER_JOIN_TOKEN" \
      --overwrite \
      --region "$REGION" >/dev/null || \
      fail "Unable to store worker join token."

    log "First Swarm manager initialized successfully."

  else

    log "Joining existing Swarm as manager via $MANAGER_IP..."

    MANAGER_JOIN_TOKEN=""
    for attempt in $(seq 1 30); do
      MANAGER_JOIN_TOKEN=$(aws ssm get-parameter \
        --name "${PARAMETER_PATH}/manager-join-token" \
        --with-decryption \
        --region "$REGION" \
        --query Parameter.Value \
        --output text 2>/dev/null || true)

      [ -n "$MANAGER_JOIN_TOKEN" ] && \
      [ "$MANAGER_JOIN_TOKEN" != "None" ] && break

      log "Manager join token not ready. Attempt ${attempt}/30."
      sleep 10
    done

    [ -n "$MANAGER_JOIN_TOKEN" ] && \
    [ "$MANAGER_JOIN_TOKEN" != "None" ] || \
      fail "Unable to retrieve Swarm manager join token."

    docker swarm join \
      --token "$MANAGER_JOIN_TOKEN" \
      "${MANAGER_IP}:2377" \
      --advertise-addr "$PRIVATE_IP" \
      || fail "Docker Swarm manager join failed."

    log "Docker Swarm manager join completed successfully."

  fi

else
  log "Docker Swarm is already active on this manager."
fi

#############################################
# Final Validation
#############################################

SWARM_STATE=$(docker info \
  --format '{{.Swarm.LocalNodeState}}' \
  2>/dev/null || true)

[ "$SWARM_STATE" = "active" ] || \
  fail "Manager Swarm state is not active."

CONTROL_AVAILABLE=$(docker info \
  --format '{{.Swarm.ControlAvailable}}' \
  2>/dev/null || true)

[ "$CONTROL_AVAILABLE" = "true" ] || \
  fail "Manager node does not have Swarm control-plane access."

log "Verified: node is an active Swarm manager."
log "CloudWatch monitoring is active."
log "Docker event and Docker service failure monitoring are active."
log "Manager remains available for Swarm control-plane duties."
log "Docker Swarm Manager Bootstrap Complete."

exit 0