#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# usage
# -------------------------------
usage() {
  cat <<EOF
Usage: ./lib/ecr/push_image_to_ecr.sh --aws-ecr-repo-name <repo> --image-name <name> --image-tag <tag>

Description:
  Creates (if needed) an AWS ECR repository, logs in, tags, and pushes the specified image.

Required arguments:
  --aws-ecr-repo-name   Name of the AWS ECR repository
  --image-name          Local image name
  --image-tag           Tag of the image to push

Environment:
  aws_region must be exported before running.

Example:
  export aws_region=eu-west-2
  ./lib/ecr/push_image_to_ecr.sh \\
    --aws-ecr-repo-name my-app \\
    --image-name my-app \\
    --image-tag latest

Options:
  -h, --help   Show this help message
EOF
}

# -------------------------------
# parse args
# -------------------------------
AWS_ECR_REPO_NAME=""; IMAGE_NAME=""; IMAGE_TAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --aws-ecr-repo-name) AWS_ECR_REPO_NAME="$2"; shift 2 ;;
    --image-name) IMAGE_NAME="$2"; shift 2 ;;
    --image-tag) IMAGE_TAG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "❌ Unknown option: $1"; usage; exit 1 ;;
  esac
done

# -------------------------------
# validate required arguments
# -------------------------------
[[ -z "${AWS_ECR_REPO_NAME}" ]] && { echo "❌ --aws-ecr-repo-name is required."; usage; exit 1; }
[[ -z "${IMAGE_NAME}" ]] && { echo "❌ --image-name is required."; usage; exit 1; }
[[ -z "${IMAGE_TAG}" ]] && { echo "❌ --image-tag is required."; usage; exit 1; }
[[ -z "${aws_region:-}" ]] && { echo "❌ aws_region is not set. Please export it."; exit 1; }

# -------------------------------
# main logic
# -------------------------------
echo "📦 Pushing image to AWS ECR"
echo "  🏷️  Repo:  ${AWS_ECR_REPO_NAME}"
echo "  🐳 Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  🌍 Region: ${aws_region}"

# create repository if missing
echo "🔧 Ensuring repository exists..."
aws ecr create-repository \
  --repository-name "${AWS_ECR_REPO_NAME}" \
  --region "${aws_region}" \
  >/dev/null 2>&1 || true

# get repo URL
AWS_ECR_REPO_URL="$(
  aws ecr describe-repositories \
    --repository-names "${AWS_ECR_REPO_NAME}" \
    --query "repositories[0].repositoryUri" \
    --output text
)"
echo "🧭 Repository URL: ${AWS_ECR_REPO_URL}"

# docker login
echo "🔐 Logging into AWS ECR..."
aws ecr get-login-password \
  --region "${aws_region}" \
  | docker login --username AWS --password-stdin "${AWS_ECR_REPO_URL}"

# tag image
echo "🏷️  Tagging image..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${AWS_ECR_REPO_URL}:${IMAGE_TAG}"

# push image
echo "🚀 Pushing image to ECR..."
docker push "${AWS_ECR_REPO_URL}:${IMAGE_TAG}"

echo "✅ Done: ${AWS_ECR_REPO_URL}:${IMAGE_TAG}"
