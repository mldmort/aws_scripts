#!/usr/bin/env bash
# Full SSC samtools flagstat run: all 9039 samples on EC2 Spot via
# genomics-spot-v2 (256 vCPU cap = ~64 concurrent at 4 vCPU/task).
# Expected wall-clock: ~10-12 hours; expected cost: ~$60.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 9039
