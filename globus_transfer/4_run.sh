#!/usr/bin/env bash
# Fifth batch: 2000 SPARK iWGS_v1.1 CRAMs (~38 TB) staged from SFARI to
# Expanse Lustre. Picks up where 3_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 6200 --limit 2000
