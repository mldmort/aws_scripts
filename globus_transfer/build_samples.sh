#!/usr/bin/env bash
# Build the full master manifest from coverage_spark_ssc/samples.csv.
# Output: samples.tsv with one row per sample, columns sample_id, src_cram, src_crai
# in Globus-path form (s3://sparkgenomics/iWGS_v1.1/... -> /SPARK/pub/iWGS_v1.1/...).
#
# This is a one-time build. Subsequent batches are sliced from samples.tsv at
# submit time via submit_transfer.sh --offset/--limit.
set -euo pipefail

SRC_CSV="$(dirname "$0")/../coverage_spark_ssc/samples.csv"
OUT="$(dirname "$0")/samples.tsv"

[[ -f "$SRC_CSV" ]] || { echo "ERROR: source manifest not found at $SRC_CSV" >&2; exit 2; }

{
  printf 'sample_id\tsrc_cram\tsrc_crai\n'
  awk -F, '
    NR == 1 { next }
    {
      sample_id = $1
      cram_url  = $2
      sub("^s3://sparkgenomics/iWGS_v1.1/", "/SPARK/pub/iWGS_v1.1/", cram_url)
      printf "%s\t%s\t%s.crai\n", sample_id, cram_url, cram_url
    }
  ' "$SRC_CSV"
} > "$OUT"

echo "wrote $OUT"
wc -l "$OUT"
