#!/usr/bin/env bash
# Sixth batch: 2000 SPARK iWGS_v1.1 CRAMs (~38 TB) staged from SFARI to
# Expanse Lustre. Picks up where 4_run.sh left off.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 8200 --limit 2000
