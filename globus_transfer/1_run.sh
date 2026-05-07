#!/usr/bin/env bash
# Second batch: 2000 SPARK iWGS_v1.1 CRAMs (~38 TB) staged from SFARI to
# Expanse Lustre. Picks up where 0_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 100 --limit 2000
