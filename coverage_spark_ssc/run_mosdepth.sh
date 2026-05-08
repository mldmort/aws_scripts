#!/usr/bin/env bash
# Per-sample mosdepth worker for the SPARK iWGS_v1.1 coverage run.
# Designed to run inside the Batch container, but also runnable locally for testing.
#
# Required env vars:
#   SAMPLES_S3_URL      e.g. s3://sebat-genomics-work/coverage_spark_ssc/_inputs/samples.csv
#   OUTPUT_S3_PREFIX    e.g. s3://sebat-genomics-work/coverage_spark_ssc/results/
#   REFERENCE_S3_URL    e.g. s3://sebat-genomics-work/refs/GRCh38/GRCh38_full_analysis_set_plus_decoy_hla.fa
#                       Worker also fetches sibling .fai (REFERENCE_S3_URL + ".fai")
#   SFARI_ACCESS_KEY    sfari access key (reads s3://sparkgenomics)
#   SFARI_SECRET_KEY    sfari secret
# Optional:
#   AWS_BATCH_JOB_ARRAY_INDEX   provided by Batch; or pass index as $1
#   THREADS             default 4
#
# Default credentials (instance role) are used for the samples.csv fetch and
# the result upload. Sfari keys are scoped to the CRAM/CRAI download only.
set -euo pipefail

INDEX="${AWS_BATCH_JOB_ARRAY_INDEX:-${1:-}}"
[[ -n "$INDEX" ]] || { echo "ERROR: missing INDEX (set AWS_BATCH_JOB_ARRAY_INDEX or pass arg)" >&2; exit 2; }

: "${SAMPLES_S3_URL:?required}"
: "${OUTPUT_S3_PREFIX:?required}"
: "${REFERENCE_S3_URL:?required}"
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
THREADS="${THREADS:-4}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo ">> fetching samples.csv"
aws s3 cp "$SAMPLES_S3_URL" samples.csv >/dev/null

# Header is row 1; array index 0 maps to row 2.
ROW=$((INDEX + 2))
LINE="$(awk -v r="$ROW" 'NR==r' samples.csv)"
[[ -n "$LINE" ]] || { echo "ERROR: index $INDEX out of range (row $ROW empty)" >&2; exit 3; }

SAMPLE_ID="${LINE%%,*}"
CRAM_URL="${LINE#*,}"
CRAI_URL="${CRAM_URL}.crai"
echo "sample: $SAMPLE_ID"
echo "cram:   $CRAM_URL"

echo ">> downloading CRAM + CRAI (sfari creds)"
AWS_ACCESS_KEY_ID="$SFARI_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SFARI_SECRET_KEY" \
  aws s3 cp "$CRAM_URL" "${SAMPLE_ID}.cram"
AWS_ACCESS_KEY_ID="$SFARI_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SFARI_SECRET_KEY" \
  aws s3 cp "$CRAI_URL" "${SAMPLE_ID}.cram.crai"

echo ">> downloading reference FASTA + .fai (default creds)"
REF_BASENAME="$(basename "$REFERENCE_S3_URL")"
aws s3 cp "$REFERENCE_S3_URL"     "$REF_BASENAME"
aws s3 cp "${REFERENCE_S3_URL}.fai" "${REF_BASENAME}.fai"

echo ">> running mosdepth (threads=$THREADS)"
mosdepth --threads "$THREADS" --no-per-base --by 1000 \
    --fasta "$REF_BASENAME" \
    "$SAMPLE_ID" "${SAMPLE_ID}.cram"

echo ">> uploading outputs"
DEST="${OUTPUT_S3_PREFIX%/}/${SAMPLE_ID}/"
for f in \
    "${SAMPLE_ID}.mosdepth.summary.txt" \
    "${SAMPLE_ID}.mosdepth.global.dist.txt" \
    "${SAMPLE_ID}.mosdepth.region.dist.txt" \
    "${SAMPLE_ID}.regions.bed.gz" \
    "${SAMPLE_ID}.regions.bed.gz.csi"; do
  [[ -f "$f" ]] && aws s3 cp "$f" "${DEST}${f}"
done

echo "DONE: $SAMPLE_ID"
