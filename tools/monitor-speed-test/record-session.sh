#!/usr/bin/env bash
# record-session.sh — starts Catavan recording what goes to the default sound output (PipeWire/Pulse monitor) and
# the speed filter log (MONITORSPEED_LOG). Close Catavan to finish. Other system sounds are recorded too: keep only
# Catavan playing.
# Usage: tools/monitor-speed-test/record-session.sh [folder]   (default: ~/catavan-session)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${1:-$HOME/catavan-session}"; mkdir -p "$OUT"
parecord --device=@DEFAULT_MONITOR@ --format=float32le --rate=48000 --channels=2 --raw "$OUT/output.raw" &
REC=$!
trap 'kill $REC 2>/dev/null || true' EXIT
date +%s.%N > "$OUT/start.txt"
MONITORSPEED_LOG="$OUT/speed.log" "$HERE/../../build.sh" run || true
echo "Recorded in $OUT (output.raw, speed.log)"
