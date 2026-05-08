#!/usr/bin/env bash
# Submit a Batch array job over the SSC WGS samples.
# Reuses the existing image + job definition from coverage_spark_ssc; SSC-specific
# paths and the sfari-keys-needed-for-Get-from-us-east-1 are passed at submit time
# via container overrides.
#
# Usage:
#   SFARI_ACCESS_KEY=... SFARI_SECRET_KEY=... \
#     ./submit_array.sh <size> [--name <jobname>] [--queue <queue>]
#
# Examples:
#   ./submit_array.sh 1                     # 1-sample smoke (no array)
#   ./submit_array.sh 5                     # 5-sample test array
#   ./submit_array.sh 9039                  # full SSC run
set -euo pipefail

SIZE="${1:?usage: submit_array.sh <size>}"
shift || true

REGION=us-east-1
JOB_NAME="coverage-ssc-$(date -u +%Y%m%dT%H%M%SZ)"
# Default to Fargate (genomics-fargate-queue + coverage-ssc-mosdepth-fargate job
# def). Fargate gives each task its own ephemeralStorage (50 GiB here) so the
# 25-GB SSC CRAMs don't bust the worker disk like they did on EC2 Spot.
QUEUE="genomics-fargate-queue"
JOB_DEF="coverage-ssc-mosdepth-fargate"
SAMPLES_S3_URL="s3://sebat-genomics-work/coverage_ssc/_inputs/samples.csv"
OUTPUT_S3_PREFIX="s3://sebat-genomics-work/coverage_ssc/results/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)            JOB_NAME="$2";          shift 2 ;;
    --queue)           QUEUE="$2";             shift 2 ;;
    --jobdef)          JOB_DEF="$2";           shift 2 ;;
    --samples)         SAMPLES_S3_URL="$2";    shift 2 ;;
    --output)          OUTPUT_S3_PREFIX="$2";  shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

: "${SFARI_ACCESS_KEY:?required (sfari access key id)}"
: "${SFARI_SECRET_KEY:?required (sfari secret access key)}"

# Build env-vars block. For non-array jobs (size=1), Batch doesn't set
# AWS_BATCH_JOB_ARRAY_INDEX, and we can't override it via env (Batch
# reserves all AWS_BATCH_* names). Pass the index as a positional arg
# instead, which run_mosdepth.sh will read from $1.
ENV_BLOCK="{\"name\": \"SFARI_ACCESS_KEY\", \"value\": \"$SFARI_ACCESS_KEY\"},
  {\"name\": \"SFARI_SECRET_KEY\", \"value\": \"$SFARI_SECRET_KEY\"},
  {\"name\": \"SAMPLES_S3_URL\",   \"value\": \"$SAMPLES_S3_URL\"},
  {\"name\": \"OUTPUT_S3_PREFIX\", \"value\": \"$OUTPUT_S3_PREFIX\"}"
OVERRIDES="{\"environment\": [$ENV_BLOCK]"
if [[ "$SIZE" -le 1 ]]; then
  OVERRIDES="${OVERRIDES}, \"command\": [\"0\"]"
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
