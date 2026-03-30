#!/usr/bin/env bash
set -euo pipefail

# Incoming arguments
JOB=${1:-}
NAMESPACE=${2:-}
RENOVATE_OPERATOR_WEBHOOK_URL=${3:-}
FORGEJO_EVENT=${4:-}

curl -v -X POST \
  -H "Content-Type: application/json" \
  -H "X-Forgejo-Event: ${FORGEJO_EVENT}" \
  -d @"${WEBHOOK_PAYLOAD_FILE}" \
  "${RENOVATE_OPERATOR_WEBHOOK_URL}/webhook/v1/forgejo?job=${JOB}&namespace=${NAMESPACE}"
