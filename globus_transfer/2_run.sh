#!/usr/bin/env bash
# Third batch: 2100 SPARK iWGS_v1.1 CRAMs (~40 TB) staged from SFARI to
# Expanse Lustre. Picks up where 1_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 2100 --limit 2100
