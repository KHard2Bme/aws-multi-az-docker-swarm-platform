#!/bin/bash

# ==========================================
# Docker Service Failure Monitor
# ==========================================
# Detects when the Docker service becomes
# inactive and logs a WorkerNodeFailure or
# ManagerNodeFailure event.
#
# Usage:
#   docker_service_monitor.sh worker
#   docker_service_monitor.sh manager
# ==========================================

NODE_ROLE="$1"
LOG_FILE="/var/log/docker-events.log"

if [[ "$NODE_ROLE" != "worker" && "$NODE_ROLE" != "manager" ]]; then
    echo "Usage: $0 {worker|manager}"
    exit 1
fi

if [[ "$NODE_ROLE" == "worker" ]]; then
    FAILURE_EVENT="WorkerNodeFailure"
else
    FAILURE_EVENT="ManagerNodeFailure"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] DockerServiceMonitorStarted role=${NODE_ROLE}" >> "$LOG_FILE"

FAILURE_REPORTED=false

while true; do

    if ! systemctl is-active --quiet docker; then

        # Prevent the same failure from being logged repeatedly
        if [[ "$FAILURE_REPORTED" == "false" ]]; then

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${FAILURE_EVENT} docker_service=inactive role=${NODE_ROLE} hostname=$(hostname)" \
                >> "$LOG_FILE"

            FAILURE_REPORTED=true
        fi

    else

        # Docker recovered — allow future failures to be detected
        if [[ "$FAILURE_REPORTED" == "true" ]]; then

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] DockerServiceRecovered role=${NODE_ROLE} hostname=$(hostname)" \
                >> "$LOG_FILE"

            FAILURE_REPORTED=false
        fi

    fi

    sleep 5

done