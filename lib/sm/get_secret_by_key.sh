#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<EOF
Usage: ./lib/sm/get_secret_by_key.sh --region <region> --secret-id <secret-id> --key <key>

Options:
  --region      AWS region (e.g., us-east-1)
  --secret-id   Secret name or ARN in AWS Secrets Manager
  --key         Key name inside the secret JSON to extract
  -h, --help    Show this help message and exit

Example:
  ./lib/sm/get_secret_by_key.sh --region us-east-1 --secret-id my-db-secret --key password
EOF
}

region=""
secret_id=""
key=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) region="$2"; shift 2 ;;
    --secret-id) secret_id="$2"; shift 2 ;;
    --key) key="$2"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Validate
if [[ -z "$region" || -z "$secret_id" || -z "$key" ]]; then
  echo "❌ Missing required arguments."
  show_help
  exit 1
fi

# Get the full secret string using the first script
secret_json="$(./lib/sm/get_secret_all.sh --region "$region" --secret-id "$secret_id")"

echo "$secret_json" | jq -r --arg k "$key" '.[$k]'
