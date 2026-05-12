#!/usr/bin/env bash
# 5-sample test array: verifies array dispatch + concurrency before the
# full SSC run.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 5
