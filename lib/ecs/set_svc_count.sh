#!/usr/bin/env bash
set -euo pipefail

# ─── Colors ────────────────────────────────────────────────────────────────
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# ─── Help ──────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
Usage:
  ecs_set_count.sh <cluster> <service> <count>

Description:
  Manually set or update the desired task count for an ECS service.
  Useful when Terraform ignores desired_count (via ignore_changes)
  and you want to control it manually.

Options:
  -h, --help      Show this help message.

Examples:
  ecs_set_count.sh test-example-ecs-cluster test-example-a-api-ecs-svc 3
  ecs_set_count.sh my-cluster my-service 0

Notes:
  - Calls: aws ecs update-service --desired-count <count>
  - Ensure you are authenticated with AWS CLI and have ECS permissions.
  - Setting count to 0 stops all running tasks.
EOF
}

# ─── Argument Parsing ──────────────────────────────────────────────────────
if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ $# -ne 3 ]]; then
    echo "${RED}❌ Error: Invalid arguments.${RESET}"
    echo "Run './ecs_set_count.sh --help' for usage info."
    exit 1
fi

CLUSTER="$1"
SERVICE="$2"
COUNT="$3"

# ─── Check Cluster ─────────────────────────────────────────────────────────
echo -n "🔍 Checking ECS cluster '${YELLOW}${CLUSTER}${RESET}'... "
CLUSTER_STATUS=$(aws ecs describe-clusters \
  --clusters "$CLUSTER" \
  --query "clusters[0].status" \
  --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$CLUSTER_STATUS" != "ACTIVE" ]]; then
    echo "${RED}not found or inactive (status: ${CLUSTER_STATUS}).${RESET}"
    exit 1
else
    echo "${GREEN}found.${RESET}"
fi

# ─── Check Service ─────────────────────────────────────────────────────────
echo -n "🔍 Checking ECS service '${YELLOW}${SERVICE}${RESET}'... "
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER" \
    --services "$SERVICE" \
    --query "services[0].status" \
    --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "$SERVICE_STATUS" == "INACTIVE" || "$SERVICE_STATUS" == "None" || "$SERVICE_STATUS" == "NOT_FOUND" ]]; then
    echo "${RED}not found or inactive.${RESET}"
    exit 1
else
    echo "${GREEN}found.${RESET}"
fi

# ─── Update Desired Count ─────────────────────────────────────────────────
echo "⚙️  Updating ECS service desired count to ${YELLOW}${COUNT}${RESET}..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count "$COUNT" \
  >/dev/null

echo "${GREEN}✅ Desired count updated successfully.${RESET}"

# ─── Show Final State ─────────────────────────────────────────────────────
echo "📊 Current ECS service state:"
aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE" \
  --query "services[0].{Service:serviceName,DesiredCount:desiredCount,RunningCount:runningCount,Status:status}" \
  --output table
