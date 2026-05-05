#!/usr/bin/env bash
# Build the worker image and push to ECR. Run from the orchestrator EC2
# (already linux/amd64, so plain `docker build` is fine — no buildx needed).
# The ECR repo must already exist; the orchestrator's instance role does not
# have ecr:CreateRepository. Create it once from a host that does, e.g.:
#   aws --profile default --region us-east-1 ecr create-repository \
#       --repository-name coverage-spark-ssc
set -euo pipefail

REGION="${REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-640838474376}"
REPO="${REPO:-coverage-spark-ssc}"
TAG="${TAG:-v1}"

REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO}:${TAG}"

echo ">> verifying ECR repo $REPO exists"
aws --region "$REGION" ecr describe-repositories --repository-names "$REPO" >/dev/null 2>&1 || {
  echo "ERROR: ECR repo $REPO does not exist." >&2
  echo "Create it from a host with ecr:CreateRepository perms:" >&2
  echo "  aws --profile default --region $REGION ecr create-repository --repository-name $REPO" >&2
  exit 1
}

echo ">> docker login to $REGISTRY"
aws --region "$REGION" ecr get-login-password \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> building $IMAGE"
docker build -t "$IMAGE" "$(dirname "$0")"

echo ">> pushing $IMAGE"
docker push "$IMAGE"

echo "DONE: $IMAGE"
