#!/usr/bin/env bash
# Fourth batch: 2000 SPARK iWGS_v1.1 CRAMs (~38 TB) staged from SFARI to
# Expanse Lustre. Picks up where 2_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 4200 --limit 2000
