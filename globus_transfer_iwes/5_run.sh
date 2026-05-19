#!/usr/bin/env bash
# Shard 5 of SPARK iWES_v3 (~14k CRAMs, ~13.4 TB).
set -euo pipefail
"$(dirname "$0")/submit_shard.sh" 5
