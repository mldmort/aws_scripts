#!/usr/bin/env bash
# Tests S3 write permission on the `sebat` profile (SDSC Ceph at sebat.s3.sdsc.edu)
# by uploading a small text file under s3://sebat/tests_milad/<utc-timestamp>/ and reading it back.
set -euo pipefail

PROFILE="sebat"
BUCKET="sebat"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
KEY="tests_milad/${TIMESTAMP}/hello.txt"
S3_URL="s3://${BUCKET}/${KEY}"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
{
  echo "S3 write-permission test"
  echo "host:    $(hostname)"
  echo "user:    $(whoami)"
  echo "utc:     $(date -u)"
  echo "profile: ${PROFILE}"
  echo "target:  ${S3_URL}"
} > "$TMP"

echo ">> uploading to ${S3_URL}"
aws --profile "${PROFILE}" s3 cp "$TMP" "${S3_URL}"

echo ">> verifying via list"
aws --profile "${PROFILE}" s3 ls "${S3_URL}"

echo ">> reading object back"
aws --profile "${PROFILE}" s3 cp "${S3_URL}" - --quiet
echo

echo "PASS: write permission confirmed."
echo "Object left in place at ${S3_URL}"
echo "Clean up with:"
echo "  aws --profile ${PROFILE} s3 rm ${S3_URL}"
