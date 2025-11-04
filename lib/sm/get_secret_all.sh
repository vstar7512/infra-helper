#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<EOF
Usage: ./lib/sm/get_secret_all.sh --region <region> --secret-id <secret-id>

Options:
  --region      AWS region (e.g., us-east-1)
  --secret-id   Secret name or ARN in AWS Secrets Manager
  -h, --help    Show this help message and exit

Example:
  ./lib/sm/get_secret_all.sh --region us-east-1 --secret-id my-db-secret
EOF
}

region=""
secret_id=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) region="$2"; shift 2 ;;
    --secret-id) secret_id="$2"; shift 2 ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "❌ Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Validate inputs
if [[ -z "$region" || -z "$secret_id" ]]; then
  echo "❌ Missing required arguments."
  show_help
  exit 1
fi

# Retrieve secret
aws secretsmanager get-secret-value \
  --region "$region" \
  --secret-id "$secret_id" \
  --query SecretString \
  --output text
