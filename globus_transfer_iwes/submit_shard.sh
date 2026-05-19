#!/usr/bin/env bash
# Submit a Globus recursive transfer for one shard of SPARK iWES_v3
# (sequence_data/0/ through sequence_data/9/).
# Each shard is ~14k CRAMs + ~14k CRAIs, ~13.4 TB.
#
# Source: SFARI Collections (guest collection)
# Destination: SDSC HPC - Expanse Lustre (mapped collection)
# Both endpoints' identity setup is the same as globus_transfer/ for WGS.
#
# IMPORTANT: the destination parent dir must be group-writable for ddp195
# (Globus maps your session to the j3guevara Linux user, not smmortazavi).
# Set it once:
#   ssh expanse_user 'mkdir -p /expanse/lustre/projects/ddp195/smmortazavi/iwes_staging
#                     chmod 2770 /expanse/lustre/projects/ddp195/smmortazavi/iwes_staging
#                     chgrp ddp195 /expanse/lustre/projects/ddp195/smmortazavi/iwes_staging'
#
# Usage:
#   ./submit_shard.sh <shard 0-9>
set -euo pipefail

SHARD="${1:?usage: submit_shard.sh <shard 0-9>}"
case "$SHARD" in
  [0-9]) : ;;
  *) echo "ERROR: shard must be a single digit 0-9, got '$SHARD'" >&2; exit 2 ;;
esac

SFARI=98f73ff6-b423-11ec-bae0-cd8db799a66a
LUSTRE=8735b734-00dc-4659-be0d-ff96beaff17b
SRC_DIR="/SPARK/pub/iWES_v3/sequence_data/${SHARD}/"
DST_DIR="/projects/ddp195/smmortazavi/iwes_staging/${SHARD}/"
LABEL="spark-iwes-shard${SHARD}-$(date -u +%Y%m%dT%H%M%SZ)"

echo ">> shard:       $SHARD"
echo ">> source:      $SFARI:$SRC_DIR"
echo ">> destination: $LUSTRE:$DST_DIR"
echo ">> label:       $LABEL"

globus transfer \
  --recursive --preserve-mtime \
  --label "$LABEL" \
  "$SFARI:$SRC_DIR" "$LUSTRE:$DST_DIR"
