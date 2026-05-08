#!/usr/bin/env bash
# Smoke test: 1 SSC sample via AWS Batch (no array).
# Requires SFARI keys in env. Run from anywhere with aws CLI configured.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 1
