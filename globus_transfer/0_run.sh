#!/usr/bin/env bash
# First batch: 100 SPARK iWGS_v1.1 CRAMs (~2 TB) as a Globus throughput test
# before scaling up to a 50 TB batch.
set -euo pipefail
"$(dirname "$0")/submit_transfer.sh" --offset 0 --limit 100
