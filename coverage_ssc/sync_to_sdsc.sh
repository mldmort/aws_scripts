#!/usr/bin/env bash
# Two-leg sync of the SSC coverage results:
#   1) AWS S3 (s3://sebat-genomics-work/coverage_ssc/results/)
#   2) Lustre staging dir on Expanse
#   3) SDSC Ceph (s3://sebat/coverage_ssc/)
#
# Run from Expanse (login or compute node). The two profiles must already
# be configured in ~/.aws/:
#   - default : AWS smmortazavi keys (read sebat-genomics-work)
#   - sebat   : SDSC Ceph keys (write s3://sebat/)
#
# Total: ~415 GB across ~45k objects. AWS S3 egress to Lustre is ~$0.09/GB
# (paid by the lab AWS account); Lustre -> Ceph is free same-site.
set -euo pipefail

SRC=s3://sebat-genomics-work/coverage_ssc/results/
DST=s3://sebat/coverage_ssc/
STAGE="${STAGE:-/expanse/lustre/projects/ddp195/smmortazavi/ssc_sync_staging}"

mkdir -p "$STAGE"
echo ">> staging dir: $STAGE"
df -h "$STAGE" | tail -1

echo
echo ">> leg 1: AWS S3 -> Lustre staging"
T0=$(date -u +%s)
aws --profile default s3 sync "$SRC" "$STAGE/" --no-progress
T1=$(date -u +%s)
echo "leg 1 took $((T1 - T0))s; staging size: $(du -sh "$STAGE" | cut -f1)"

echo
echo ">> leg 2: Lustre staging -> SDSC Ceph"
aws --profile sebat s3 sync "$STAGE/" "$DST" --no-progress
T2=$(date -u +%s)
echo "leg 2 took $((T2 - T1))s"

echo
echo ">> verify object counts"
n_src=$(aws --profile default s3 ls "$SRC" --recursive | wc -l | tr -d ' ')
n_dst=$(aws --profile sebat   s3 ls "$DST" --recursive | wc -l | tr -d ' ')
echo "src=$n_src  dst=$n_dst"
[[ "$n_src" == "$n_dst" ]] && echo "PASS" || { echo "MISMATCH"; exit 4; }

echo
echo ">> done. To reclaim Lustre space when you're sure Ceph has everything:"
echo "   rm -rf $STAGE"
