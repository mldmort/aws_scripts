#!/usr/bin/env bash
# 5-sample test array: confirms array-mode dispatch + concurrency before
# scaling up to the full ~9k SSC run.
set -euo pipefail
: "${SFARI_ACCESS_KEY:?required}"
: "${SFARI_SECRET_KEY:?required}"
"$(dirname "$0")/submit_array.sh" 5
