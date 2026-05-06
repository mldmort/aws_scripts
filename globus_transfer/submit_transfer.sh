#!/usr/bin/env bash
# Submit a Globus batch transfer for a slice of samples.tsv (the master manifest).
# Source: SFARI Collections (guest collection)
# Destination: SDSC HPC - Expanse Lustre (mapped collection)
# All files land flat under DST_PREFIX as <sample_id>.cram and <sample_id>.cram.crai.
#
# Usage:
#   ./submit_transfer.sh --offset N --limit M [--dst-prefix /some/path]
#
# Examples:
#   ./submit_transfer.sh --offset 0 --limit 100        # first 100 samples (smoke)
#   ./submit_transfer.sh --offset 100 --limit 2500     # next 2,500 (~50 TB batch)
#
# Prerequisites:
#   - globus-cli installed and authenticated
#   - Active session has BOTH ACCESS-CI identity (for SDSC mapping) and
#     a SFARI-permitted identity (sebatlab-linked).
#   - DST_PREFIX exists on Expanse with permissions that let the GCS-mapped
#     Linux user write into it (currently j3guevara per SDSC mapping).
set -euo pipefail

OFFSET=0
LIMIT=
DST_PREFIX=/projects/ddp195/smmortazavi/globus_staging

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offset)     OFFSET="$2";     shift 2 ;;
    --limit)      LIMIT="$2";      shift 2 ;;
    --dst-prefix) DST_PREFIX="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$LIMIT" ]] || {
  echo "ERROR: --limit is required (refusing to default to 'all 12k samples')" >&2
  exit 2
}

SFARI=98f73ff6-b423-11ec-bae0-cd8db799a66a
LUSTRE=8735b734-00dc-4659-be0d-ff96beaff17b
SAMPLES="$(dirname "$0")/samples.tsv"
LABEL="${LABEL:-spark-iwgs-off${OFFSET}-lim${LIMIT}-$(date -u +%Y%m%dT%H%M%SZ)}"

[[ -f "$SAMPLES" ]] || { echo "ERROR: $SAMPLES not found (run build_samples.sh first)" >&2; exit 2; }

TOTAL=$(awk -F'\t' 'NR>1 {n++} END {print n+0}' "$SAMPLES")
echo ">> master manifest: $TOTAL samples"
echo ">> slice:           offset=$OFFSET limit=$LIMIT (=> $((LIMIT * 2)) transfer items)"
echo ">> destination:     $LUSTRE:$DST_PREFIX/"
echo ">> label:           $LABEL"

awk -F'\t' -v dst="$DST_PREFIX" -v offset="$OFFSET" -v limit="$LIMIT" '
  NR == 1 { next }
  NR > offset + 1 && NR <= offset + 1 + limit {
    sid = $1; cram = $2; crai = $3
    printf "%s %s/%s.cram\n",      cram, dst, sid
    printf "%s %s/%s.cram.crai\n", crai, dst, sid
  }
' "$SAMPLES" \
  | globus transfer "$SFARI" "$LUSTRE" \
      --label "$LABEL" \
      --preserve-mtime \
      --batch -
