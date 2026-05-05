#!/usr/bin/env bash
# Submit a Batch array job covering N samples from samples.csv.
# Sfari read keys are passed via container overrides; submit from a host that
# has the sfari keys in env (or set them inline).
#
# Usage:
#   SFARI_ACCESS_KEY=... SFARI_SECRET_KEY=... \
#     ./submit_array.sh <size> [--name <jobname>] [--queue <queue>]
#
# Examples:
#   ./submit_array.sh 1                      # smoke-test, single sample (index 0)
#   ./submit_array.sh 5                      # 5-sample test array
#   ./submit_array.sh 12519                  # full SPARK iWGS_v1.1 run
set -euo pipefail

SIZE="${1:?usage: submit_array.sh <size>}"
shift || true

JOB_NAME="coverage-spark-ssc-$(date -u +%Y%m%dT%H%M%SZ)"
QUEUE="genomics-queue"
JOB_DEF="coverage-spark-ssc-mosdepth"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)  JOB_NAME="$2"; shift 2 ;;
    --queue) QUEUE="$2";    shift 2 ;;
    --jobdef) JOB_DEF="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${SFARI_ACCESS_KEY:?required (sfari access key id)}"
: "${SFARI_SECRET_KEY:?required (sfari secret access key)}"

ARGS=(
  --job-name "$JOB_NAME"
  --job-queue "$QUEUE"
  --job-definition "$JOB_DEF"
  --container-overrides "{
    \"environment\": [
      {\"name\": \"SFARI_ACCESS_KEY\", \"value\": \"$SFARI_ACCESS_KEY\"},
      {\"name\": \"SFARI_SECRET_KEY\", \"value\": \"$SFARI_SECRET_KEY\"}
    ]
  }"
)

if [[ "$SIZE" -gt 1 ]]; then
  ARGS+=(--array-properties "size=$SIZE")
fi

aws batch submit-job "${ARGS[@]}"
