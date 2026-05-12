#!/usr/bin/env bash
# Pull all per-sample flagstat TSVs from S3 and concatenate into one master
# table with the same 21-column layout as the colleague's SPARK iWGS_v1.1
# master table. Run after the Batch array completes.
#
# Output: ./SSC.cram_stats.tsv
set -euo pipefail

SRC="${SRC:-s3://sebat-genomics-work/flagstat_ssc/results/}"
OUT="${OUT:-$(dirname "$0")/SSC.cram_stats.tsv}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo ">> downloading TSV rows from $SRC"
aws --profile default s3 sync "$SRC" "$STAGE/" --exclude "*.json" --no-progress

echo ">> concatenating into $OUT"
{
  printf 'spid\ttotal\tprimary\tsecondary\tsupplementary\tduplicates\tprimary_duplicates\tmapped\tmapped_pct\tprimary_mapped\tprimary_mapped_pct\tpaired\tread1\tread2\tproperly_paired\tproperly_paired_pct\tpaired_and_mate_mapped\tsingletons\tsingletons_pct\tmate_mapped_diff_chr\tmate_mapped_diff_chr_pct\n'
  find "$STAGE" -name '*.tsv' -print0 | xargs -0 cat | sort
} > "$OUT"

n=$(awk 'NR>1' "$OUT" | wc -l | tr -d ' ')
echo "wrote $OUT  ($n samples)"
