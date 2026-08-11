#!/bin/bash
#
# cloudwatch_dashboard_update.sh
#
# Updates an existing CloudWatch Dashboard by adding three custom
# Engineering for Failure metric widgets.
#
# Prerequisites:
#   - AWS CLI configured
#   - jq installed
#   - Dashboard already exists
#

set -euo pipefail

DASHBOARD_NAME="${1:-EngineeringForFailure}"
TMP_JSON="dashboard.json"

command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required."; exit 1; }

echo "Retrieving dashboard: ${DASHBOARD_NAME}..."

aws cloudwatch get-dashboard \
  --dashboard-name "${DASHBOARD_NAME}" \
  --query DashboardBody \
  --output text > "${TMP_JSON}"

echo "Adding Engineering for Failure widgets..."

jq '
.widgets += [
  {
    "type":"metric",
    "x":0,"y":18,"width":8,"height":6,
    "properties":{
      "title":"Container Failure Count",
      "view":"timeSeries",
      "region":"us-east-1",
      "stat":"Sum",
      "metrics":[["EngineeringForFailure","ContainerFailureCount"]]
    }
  },
  {
    "type":"metric",
    "x":8,"y":18,"width":8,"height":6,
    "properties":{
      "title":"Worker Node Failure Count",
      "view":"timeSeries",
      "region":"us-east-1",
      "stat":"Sum",
      "metrics":[["EngineeringForFailure","WorkerNodeFailureCount"]]
    }
  },
  {
    "type":"metric",
    "x":16,"y":18,"width":8,"height":6,
    "properties":{
      "title":"Manager Node Failure Count",
      "view":"timeSeries",
      "region":"us-east-1",
      "stat":"Sum",
      "metrics":[["EngineeringForFailure","ManagerNodeFailureCount"]]
    }
  }
]
' "${TMP_JSON}" > dashboard_updated.json

echo "Uploading updated dashboard..."

aws cloudwatch put-dashboard \
  --dashboard-name "${DASHBOARD_NAME}" \
  --dashboard-body file://dashboard_updated.json

rm -f "${TMP_JSON}" dashboard_updated.json

echo
echo "Dashboard successfully updated."
echo "Dashboard: ${DASHBOARD_NAME}"
echo "Added widgets:"
echo "  - Container Failure Count"
echo "  - Worker Node Failure Count"
echo "  - Manager Node Failure Count"
