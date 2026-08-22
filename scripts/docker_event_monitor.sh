#!/bin/bash
#
# docker_event_monitor.sh
# Engineering for Failure - Docker Swarm Event Monitor
#
# Monitors:
#   - Container failures (die/stop)
#   - Docker daemon availability
# Produces log events matching CloudWatch metric filters:
#   ContainerFailure
#   WorkerNodeFailure
#   ManagerNodeFailure

set -euo pipefail

LOGFILE="/var/log/docker-events.log"
STATEFILE="/tmp/docker-daemon-state"

touch "$LOGFILE"
chmod 644 "$LOGFILE"

HOST=$(hostname)

ROLE="worker"
if docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -qi true; then
    ROLE="manager"
fi

echo "$(date '+%F %T') Docker Event Monitor Started role=${ROLE} host=${HOST}" >> "$LOGFILE"

monitor_containers() {
    docker events \
        --filter type=container \
        --filter event=die \
        --filter event=stop |
    while read -r line; do
        TS=$(date '+%F %T')
        CID=$(echo "$line" | awk '{print $4}')
        EVENT=$(echo "$line" | awk '{print $3}')
        echo "$TS ContainerFailure host=${HOST} container=${CID} event=${EVENT}" >> "$LOGFILE"
    done
}

monitor_daemon() {
    LAST="unknown"
    while true; do
        if systemctl is-active --quiet docker; then
            CUR="active"
        else
            CUR="inactive"
        fi

        if [ "$CUR" != "$LAST" ]; then
            TS=$(date '+%F %T')
            if [ "$CUR" = "inactive" ]; then
                if [ "$ROLE" = "manager" ]; then
                    echo "$TS ManagerNodeFailure host=${HOST} docker=inactive" >> "$LOGFILE"
                else
                    echo "$TS WorkerNodeFailure host=${HOST} docker=inactive" >> "$LOGFILE"
                fi
            else
                if [ "$ROLE" = "manager" ]; then
                    echo "$TS ManagerNodeRecovered host=${HOST} docker=active" >> "$LOGFILE"
                else
                    echo "$TS WorkerNodeRecovered host=${HOST} docker=active" >> "$LOGFILE"
                fi
            fi
            LAST="$CUR"
            echo "$CUR" > "$STATEFILE"
        fi
        sleep 15
    done
}

monitor_containers &
monitor_daemon