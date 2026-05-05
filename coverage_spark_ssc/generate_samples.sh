#!/usr/bin/env bash
# Build samples.csv from s3://sparkgenomics/iWGS_v1.1/cram/.
# One row per .cram with a sibling .cram.crai. Columns: sample_id,cram_url
set -euo pipefail

PROFILE="sfari"
PREFIX="s3://sparkgenomics/iWGS_v1.1/cram/"
OUT="$(dirname "$0")/samples.csv"

LISTING="$(mktemp)"
trap 'rm -f "$LISTING"' EXIT

aws --profile "$PROFILE" s3 ls "$PREFIX" --recursive > "$LISTING"

{
  echo "sample_id,cram_url"
  awk -v prefix="s3://sparkgenomics/" '
    $4 ~ /\.cram$/  { cram[$4] = 1 }
    $4 ~ /\.cram\.crai$/ { crai[substr($4, 1, length($4) - 5)] = 1 }
    END {
      for (k in cram) {
        if (k in crai) {
          n = split(k, parts, "/")
          fname = parts[n]
          sub(/\.cram$/, "", fname)
          print fname "," prefix k
        }
      }
    }
  ' "$LISTING" | sort
} > "$OUT"

echo "Wrote $OUT"
wc -l "$OUT"
