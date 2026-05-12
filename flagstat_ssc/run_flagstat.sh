#!/usr/bin/env bash
# Per-sample samtools flagstat worker for the SSC WGS coverage QC pipeline.
# Streams the CRAM directly from s3://sscwgs-hg38/ (no local download) via
# htslib's S3 plugin, then writes a single 21-column TSV row matching the
# colleague's SPARK iWGS_v1.1 master table format.
#
# Required env vars:
#   SAMPLES_S3_URL      s3://.../samples.csv  (cols: sample_id,cram_url)
#   OUTPUT_S3_PREFIX    s3://.../<sample>.tsv  prefix
#   SFARI_ACCESS_KEY    sfari access key (reads s3://sscwgs-hg38)
#   SFARI_SECRET_KEY    sfari secret
# Optional:
#   AWS_BATCH_JOB_ARRAY_INDEX   provided by Batch; or pass index as $1
#   THREADS             default 4
set -euo pipefail

INDEX="${1:-${AWS_BATCH_JOB_ARRAY_INDEX:-}}"
[[ -n "$INDEX" ]] || { echo "ERROR: missing INDEX (set AWS_BATCH_JOB_ARRAY_INDEX or pass arg)" >&2; exit 2; }

: "${SAMPLES_S3_URL:?required}"
: "${OUTPUT_S3_PREFIX:?required}"
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
THREADS="${THREADS:-4}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

echo ">> fetching samples.csv"
aws s3 cp "$SAMPLES_S3_URL" samples.csv >/dev/null

ROW=$((INDEX + 2))
LINE="$(awk -v r="$ROW" 'NR==r' samples.csv)"
[[ -n "$LINE" ]] || { echo "ERROR: index $INDEX out of range (row $ROW empty)" >&2; exit 3; }

SAMPLE_ID="${LINE%%,*}"
CRAM_URL="${LINE#*,}"
echo "sample: $SAMPLE_ID"
echo "cram:   $CRAM_URL"

echo ">> samtools flagstat (streaming, JSON output)"
AWS_ACCESS_KEY_ID="$SFARI_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$SFARI_SECRET_KEY" \
  samtools flagstat -@ "$THREADS" -O json "$CRAM_URL" > flagstat.json

echo ">> parsing JSON -> 21-column TSV row"
python3 - "$SAMPLE_ID" flagstat.json > "${SAMPLE_ID}.tsv" <<'PY'
import json, sys
sample = sys.argv[1]
with open(sys.argv[2]) as f:
    d = json.load(f)
qc = d["QC-passed reads"]
def n(k): return qc.get(k, 0)
# Order: spid, total, primary, secondary, supplementary, duplicates,
# primary_duplicates, mapped, mapped_pct, primary_mapped, primary_mapped_pct,
# paired, read1, read2, properly_paired, properly_paired_pct,
# paired_and_mate_mapped, singletons, singletons_pct,
# mate_mapped_diff_chr, mate_mapped_diff_chr_pct (= mapQ>=5 count, not actually a %)
fields = [
    sample,
    n("total"),
    n("primary"),
    n("secondary"),
    n("supplementary"),
    n("duplicates"),
    n("primary duplicates"),
    n("mapped"),
    n("mapped %"),
    n("primary mapped"),
    n("primary mapped %"),
    n("paired in sequencing"),
    n("read1"),
    n("read2"),
    n("properly paired"),
    n("properly paired %"),
    n("with itself and mate mapped"),
    n("singletons"),
    n("singletons %"),
    n("with mate mapped to a different chr"),
    n("with mate mapped to a different chr (mapQ >= 5)"),
]
print("\t".join(str(x) for x in fields))
PY

echo ">> uploading"
aws s3 cp "${SAMPLE_ID}.tsv"   "${OUTPUT_S3_PREFIX%/}/${SAMPLE_ID}.tsv"
aws s3 cp flagstat.json        "${OUTPUT_S3_PREFIX%/}/${SAMPLE_ID}.json"

echo "DONE: $SAMPLE_ID"
