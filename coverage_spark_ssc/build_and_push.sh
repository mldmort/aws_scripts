#!/usr/bin/env bash
# Build the worker image and push to ECR. Run from the orchestrator EC2
# (or anywhere that has docker + ECR auth). x86_64 build is required since
# Batch runs on linux/amd64 instances.
set -euo pipefail

REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-640838474376}"
REPO="${REPO:-coverage-spark-ssc}"
TAG="${TAG:-v1}"

REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:${TAG}"

echo ">> ensuring repo exists"
aws --region "$REGION" ecr describe-repositories --repository-names "$REPO" >/dev/null 2>&1 \
  || aws --region "$REGION" ecr create-repository --repository-name "$REPO" >/dev/null

echo ">> docker login to $REGISTRY"
aws --region "$REGION" ecr get-login-password \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> building $IMAGE"
docker buildx build --platform linux/amd64 -t "$IMAGE" --push "$(dirname "$0")"

echo "DONE: $IMAGE"
