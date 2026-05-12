#!/usr/bin/env bash
# Submit a Batch array job over the SSC samples.csv for samtools flagstat.
# Uses the EC2 Spot compute env (genomics-queue / genomics-spot-v2); streams
# CRAMs from S3 so no local disk pressure.
#
# Usage:
#   SFARI_ACCESS_KEY=... SFARI_SECRET_KEY=... ./submit_array.sh <size> [--start N]
#
# Examples:
#   ./submit_array.sh 1            # 1-sample smoke
#   ./submit_array.sh 5            # 5-sample test array
#   ./submit_array.sh 9039         # full SSC run
#   ./submit_array.sh 5 --start 100  # retry indices 100..104 only
set -euo pipefail

SIZE="${1:?usage: submit_array.sh <size> [--start N]}"
shift || true

REGION=us-east-1
JOB_NAME="flagstat-ssc-$(date -u +%Y%m%dT%H%M%SZ)"
QUEUE="genomics-queue"
JOB_DEF="flagstat-ssc"
START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)  JOB_NAME="$2"; shift 2 ;;
    --queue) QUEUE="$2";    shift 2 ;;
    --jobdef) JOB_DEF="$2"; shift 2 ;;
    --start) START="$2";    shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${SFARI_ACCESS_KEY:?required (sfari access key id)}"
: "${SFARI_SECRET_KEY:?required (sfari secret access key)}"

# Env block. For size=1 we also pass the start index via command override
# because AWS Batch reserves AWS_BATCH_JOB_ARRAY_INDEX and won't honor env
# overrides for it; the worker reads $1 as a fallback.
ENV_BLOCK="{\"name\": \"SFARI_ACCESS_KEY\", \"value\": \"$SFARI_ACCESS_KEY\"},
  {\"name\": \"SFARI_SECRET_KEY\", \"value\": \"$SFARI_SECRET_KEY\"}"
OVERRIDES="{\"environment\": [$ENV_BLOCK]"
if [[ "$SIZE" -le 1 ]]; then
  OVERRIDES="${OVERRIDES}, \"command\": [\"$START\"]"
fi
OVERRIDES="${OVERRIDES}}"

ARGS=(
  --region "$REGION"
  --job-name "$JOB_NAME"
  --job-queue "$QUEUE"
  --job-definition "$JOB_DEF"
  --container-overrides "$OVERRIDES"
)

if [[ "$SIZE" -gt 1 ]]; then
  ARGS+=(--array-properties "size=$SIZE")
fi

aws batch submit-job "${ARGS[@]}"
