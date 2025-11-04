#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: ./lib/ecr/build_image_arm64.sh --src-dir <path> --image-name <name> --image-tag <tag> [--file <Dockerfile>]"
  echo "Example: ./lib/ecr/build_image_arm64.sh. --src-dir ./app --image-name myrepo/myimg --image-tag v1 --file ./app/Dockerfile"
  exit 1
}

# parse args
SRC_DIR=""; IMAGE_NAME=""; IMAGE_TAG=""; FILE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --src-dir) SRC_DIR="${2:-}"; shift 2 ;;
    --image-name) IMAGE_NAME="${2:-}"; shift 2 ;;
    --image-tag) IMAGE_TAG="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "❌ Unknown option: $1"; usage ;;
  esac
done

# required args
[[ -z "${SRC_DIR}" ]] && echo "❌ --src-dir is required" && usage
[[ -z "${IMAGE_NAME}" ]] && echo "❌ --image-name is required" && usage
[[ -z "${IMAGE_TAG}" ]] && echo "❌ --image-tag is required" && usage

# defaults & validations
FILE="${FILE:-${SRC_DIR%/}/Dockerfile}"
[[ ! -d "${SRC_DIR}" ]] && echo "❌ SRC_DIR not found: ${SRC_DIR}" && exit 1
[[ ! -f "${FILE}" ]] && echo "❌ Dockerfile not found: ${FILE}" && exit 1

echo "📁 Context: ${SRC_DIR}"
echo "🧾 Dockerfile: ${FILE}"
echo "🏷️ Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "🧭 Platform: linux/arm64"
echo "✅ Args OK"

# build
echo "🚀 Building with buildx (will load into local Docker)..."
docker buildx build \
  "${SRC_DIR}" \
  --file "${FILE}" \
  --platform linux/arm64 \
  --load \
  -t "${IMAGE_NAME}:${IMAGE_TAG}"

echo "✅ Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"
