#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# get all outputs (JSON)
# -------------------------
get_tf_output_all() {
    local tf_state_s3_url="$1"
    aws s3 cp "$tf_state_s3_url" - 2>/dev/null | jq '.outputs' || {
        echo "❌ Failed to fetch outputs from $tf_state_s3_url" >&2
        return 1
    }
}

# -------------------------
# main
# -------------------------
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <tf_state_s3_url>"
    exit 1
fi
get_tf_output_all "$1"
