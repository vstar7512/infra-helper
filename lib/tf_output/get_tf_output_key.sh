#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# get output by key
# -------------------------
get_tf_output_key() {
    local tf_state_s3_url="$1"
    local key="$2"
    local value
    if ! value=$(
        aws s3 cp "$tf_state_s3_url" - 2>/dev/null \
        | jq -r ".outputs.${key}" 2>/dev/null
    ); then
        echo "❌ Failed to get key: $key from $tf_state_s3_url" >&2
        return 1
    fi
    if [[ -z "$value" || "$value" == "null" ]]; then
        echo "❌ Key is empty: $key in $tf_state_s3_url" >&2
        return 1
    fi
    printf '%s\n' "$value"
}

# -------------------------
# main
# -------------------------
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <tf_state_s3_url> <key>"
    exit 1
fi

get_tf_output_key "$1" "$2"
