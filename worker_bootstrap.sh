#!/bin/bash
set -u
LOG_FILE="/var/log/worker-bootstrap.log"
REGION="us-east-1"
PARAMETER_PATH="/engineering-for-failure/docker-swarm"
log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
fail(){ log "ERROR: $*"; exit 1; }
mkdir -p "$(dirname "$LOG_FILE")"; touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
log "Docker Swarm Worker Bootstrap Starting"
PRIVATE_IP=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/local-ipv4 || true)
[ -n "$PRIVATE_IP" ] || fail "Unable to determine private IP address."
log "Worker private IP: $PRIVATE_IP"
if ! command -v docker >/dev/null 2>&1; then dnf install -y docker || fail "Docker installation failed."; fi
systemctl enable docker; systemctl start docker || fail "Unable to start Docker."
systemctl is-active --quiet docker || fail "Docker service is not active."
log "Docker is running."
if ! systemctl list-unit-files | grep -q '^amazon-ssm-agent.service'; then dnf install -y amazon-ssm-agent || fail "SSM Agent installation failed."; fi
systemctl enable amazon-ssm-agent; systemctl start amazon-ssm-agent || fail "Unable to start SSM Agent."
systemctl is-active --quiet amazon-ssm-agent || fail "SSM Agent is not active."
log "SSM Agent is running."
command -v aws >/dev/null 2>&1 || fail "AWS CLI is not available."
log "AWS CLI is available."
log "Waiting for SSM Parameter Store access..."
SSM_READY=false
for attempt in $(seq 1 30); do
  if aws ssm get-parameter --name "${PARAMETER_PATH}/manager-ip" --region "$REGION" >/dev/null 2>&1; then SSM_READY=true; log "SSM Parameter Store is accessible."; break; fi
  log "SSM Parameter Store not ready. Attempt ${attempt}/30."; sleep 10
done
[ "$SSM_READY" = true ] || fail "Unable to access required SSM Parameter Store parameters."
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)
if [ "$SWARM_STATE" = active ]; then
  log "Docker Swarm is already active on this worker."
  CONTROL_AVAILABLE=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || true)
  [ "$CONTROL_AVAILABLE" = true ] && fail "This node unexpectedly has Swarm manager/control-plane access."
else
  log "Docker Swarm is inactive. Preparing to join as a worker."
fi
MANAGER_IP=$(aws ssm get-parameter --name "${PARAMETER_PATH}/manager-ip" --region "$REGION" --query Parameter.Value --output text 2>/dev/null || true)
[ -n "$MANAGER_IP" ] && [ "$MANAGER_IP" != None ] || fail "Unable to retrieve Swarm manager private IP."
log "Swarm manager IP retrieved: $MANAGER_IP"
WORKER_JOIN_TOKEN=$(aws ssm get-parameter --name "${PARAMETER_PATH}/worker-join-token" --with-decryption --region "$REGION" --query Parameter.Value --output text 2>/dev/null || true)
[ -n "$WORKER_JOIN_TOKEN" ] && [ "$WORKER_JOIN_TOKEN" != None ] || fail "Unable to retrieve Swarm worker join token."
log "Worker join token retrieved successfully."
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)
if [ "$SWARM_STATE" = active ]; then
  log "Node is already part of a Docker Swarm."
else
  log "Joining Docker Swarm as a WORKER..."
  docker swarm join --token "$WORKER_JOIN_TOKEN" "${MANAGER_IP}:2377" --advertise-addr "$PRIVATE_IP" || fail "Docker Swarm worker join failed."
  log "Docker Swarm worker join completed successfully."
fi
SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)
[ "$SWARM_STATE" = active ] || fail "Worker joined attempt completed, but Swarm state is not active."
CONTROL_AVAILABLE=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || true)
[ "$CONTROL_AVAILABLE" = true ] && fail "Worker node has Swarm control-plane access. Expected worker only."
log "Verified: node is an active Swarm worker."
log "Worker remains available for application workloads."
log "Worker node labeling will be performed from the Swarm manager."
log "Docker Swarm Worker Bootstrap Complete"
exit 0
