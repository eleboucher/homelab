#!/usr/bin/env bash
set -euo pipefail

# Incoming arguments
JOB=${1:-}
NAMESPACE=${2:-}
RENOVATE_OPERATOR_WEBHOOK_URL=${3:-}

curl -v -X POST \
  -H "Content-Type: application/json" \
  "${RENOVATE_OPERATOR_WEBHOOK_URL}/webhook/v1/forgejo?job=${JOB}&namespace=${NAMESPACE}"
