#!/usr/bin/env bash
# Smoke test: 1 SSC sample via samtools flagstat streaming on AWS Batch.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 1
