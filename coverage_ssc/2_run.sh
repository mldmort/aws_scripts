#!/usr/bin/env bash
# Full SSC WGS run: all 9039 samples in samples.csv as a Fargate Batch array.
# Fargate compute env caps total vCPU at 256, so at 4 vCPU/task expect
# ~64 concurrent and ~3 hours wall-clock.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 9039
