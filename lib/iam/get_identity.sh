#!/usr/bin/env bash
set -euo pipefail

IDENTITY_JSON=$(aws sts get-caller-identity 2>/dev/null || true)

if [[ -z "$IDENTITY_JSON" ]]; then
  echo "❌ AWS authentication failed — please check your credentials." >&2
  exit 1
fi

echo "$IDENTITY_JSON"
