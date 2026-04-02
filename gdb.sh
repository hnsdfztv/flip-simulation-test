#!/bin/bash
set -euo pipefail

GDB_BIN="${GDB_BIN:-gdb-multiarch}"
if ! command -v "$GDB_BIN" >/dev/null 2>&1; then
	GDB_BIN="gdb"
fi

"$GDB_BIN" -q -nx -nh \
-ex 'set architecture aarch64' \
-ex 'set logging enable on' \
-ex 'target remote:1234' \
-ex 'maintenance packet Qqemu.PhyMemMode:1' \
-x gdb_command.txt \
-ex 'detach' -ex 'quit'
