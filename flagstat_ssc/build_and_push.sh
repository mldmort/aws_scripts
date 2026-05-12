#!/usr/bin/env bash
# Build and push the flagstat image. Run from the orchestrator EC2 (linux/amd64,
# has Docker). ECR repo `flagstat-ssc` must already exist; create from a host
# with ecr:CreateRepository (your local laptop):
#   aws --profile default --region us-east-1 ecr create-repository --repository-name flagstat-ssc
set -euo pipefail

REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-640838474376}"
REPO="${REPO:-flagstat-ssc}"
TAG="${TAG:-v1}"

REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:${TAG}"

echo ">> docker login to $REGISTRY"
aws --region "$REGION" ecr get-login-password \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> building $IMAGE"
docker build -t "$IMAGE" "$(dirname "$0")"

echo ">> pushing $IMAGE"
docker push "$IMAGE"

echo "DONE: $IMAGE"
