#!/usr/bin/env bash
# Seventh batch: 2319 SPARK iWGS_v1.1 CRAMs (~44 TB) — final remainder of the
# 12519-sample master manifest, staged from SFARI to Expanse Lustre.
# Picks up where 5_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 10200 --limit 2319
