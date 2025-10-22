#!/usr/bin/env bash
set -euo pipefail

# Required env:
# AWS_ACCOUNT_ID, AWS_REGION, ECR_REPO_NAME, DOCKERFILE_PATH (optional), TAG (optional)
ECR_REPO_NAME=${ECR_REPO_NAME:-device-monitor}
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
TAG=${TAG:-$(git rev-parse --short HEAD)}
DOCKERFILE_PATH=${DOCKERFILE_PATH:-.}

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "AWS_ACCOUNT_ID is required (export AWS_ACCOUNT_ID or use aws sts)"
  exit 2
fi

REPO_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"

echo "Ensuring ECR repo exists..."
aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "${ECR_REPO_NAME}" --region "${AWS_REGION}" >/dev/null

echo "Logging into ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Building image ${REPO_URI}:${TAG}"
docker build -t "${REPO_URI}:${TAG}" "${DOCKERFILE_PATH}"

echo "Pushing image..."
docker push "${REPO_URI}:${TAG}"

# update latest tag
docker tag "${REPO_URI}:${TAG}" "${REPO_URI}:latest"
docker push "${REPO_URI}:latest"

echo "IMAGE=${REPO_URI}:${TAG}" > image.env
echo "Pushed ${REPO_URI}:${TAG}"
