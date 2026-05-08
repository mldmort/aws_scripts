#!/usr/bin/env bash
# Build samples.csv from the SSC WGS bucket s3://sscwgs-hg38/.
# One row per .final.cram with a paired .final.cram.crai sibling.
# Columns: sample_id,cram_url
#
# SSC layout: sscwgs-hg38/phase{1,2,3-1,3-2,4}/<SAMPLE>.final.cram
#                                              /<SAMPLE>.final.cram.crai
# sample_id = filename minus .final.cram
set -euo pipefail

PROFILE="sfari"
PHASES=(phase1 phase2 phase3-1 phase3-2 phase4)
OUT="$(dirname "$0")/samples.csv"

LISTING="$(mktemp)"
trap 'rm -f "$LISTING"' EXIT

for p in "${PHASES[@]}"; do
  aws --profile "$PROFILE" s3 ls "s3://sscwgs-hg38/${p}/" --recursive >> "$LISTING"
done

{
  echo "sample_id,cram_url"
  awk -v prefix="s3://sscwgs-hg38/" '
    $4 ~ /\.final\.cram$/       { cram[$4] = 1 }
    $4 ~ /\.final\.cram\.crai$/ { crai[substr($4, 1, length($4) - 5)] = 1 }
    END {
      for (k in cram) {
        if (k in crai) {
          n = split(k, parts, "/")
          fname = parts[n]
          sub(/\.final\.cram$/, "", fname)
          print fname "," prefix k
        }
      }
    }
  ' "$LISTING" | sort
} > "$OUT"

echo "wrote $OUT"
wc -l "$OUT"
