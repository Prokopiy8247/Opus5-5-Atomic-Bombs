#!/usr/bin/env bash
# Helper: run Godot windowed with a log, then grep for problems. Usage: tools/run.sh LOG -- args...
GODOT="/w/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
LOG="$1"; shift
cd "$(dirname "$0")/.."
timeout ${RUN_TIMEOUT:-600} "$GODOT" --path . ${GODOT_FLAGS:---resolution 1920x1080} "$@" > "$LOG" 2>&1
echo "exit=$?"
grep -E "SCRIPT ERROR|^ERROR|Parse Error|SHADER ERROR|FAIL|READY|SHOT|WARNING: .*shader" "$LOG" | grep -v "Unreferenced static string\|RID allocations\|PagedAllocator\|ObjectDB instances leaked" | head -${HEADN:-40}
