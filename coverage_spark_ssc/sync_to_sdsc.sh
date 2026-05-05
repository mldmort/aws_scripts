#!/usr/bin/env bash
# After the Batch run completes, sync results from AWS S3 (default profile)
# to the SDSC Ceph bucket via the sebat profile.
#
# Run from your local machine (or the orchestrator EC2). Both profiles must
# be configured in ~/.aws/.
set -euo pipefail

SRC="s3://sebat-genomics-work/coverage_spark_ssc/results/"
DST="s3://sebat/coverage_spark_ssc/"

echo ">> syncing $SRC -> $DST (Ceph)"
# Read from AWS using the default profile, write to Ceph using sebat profile.
# We do it in two steps so each leg uses its native endpoint:
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

aws --profile default s3 sync "$SRC" "$TMP/" --no-progress
aws --profile sebat   s3 sync "$TMP/" "$DST" --no-progress

echo ">> verifying object counts"
n_src=$(aws --profile default s3 ls "$SRC" --recursive | wc -l | tr -d ' ')
n_dst=$(aws --profile sebat   s3 ls "$DST" --recursive | wc -l | tr -d ' ')
echo "src=$n_src  dst=$n_dst"
[[ "$n_src" == "$n_dst" ]] && echo "PASS" || { echo "MISMATCH"; exit 4; }
