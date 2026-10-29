#!/usr/bin/env bash
# kdenlive-headless.sh — plays a project in Catavan itself, without window or sound, and records the audio it would play:
#   - Qt "offscreen" (OpenGL works through XWayland, nothing shows on screen), SDL "disk" (audio goes to a file);
#   - config copied from ~/.config/catavanrc to a temporary folder (yours is not changed), own TMPDIR
#     (the startup lock goes to TMPDIR/catavanlock);
#   - Play, L, K and J triggered through D-Bus (org.kde.KMainWindow.activateAction), as from the keyboard.
# Usage: [RAPID=1|2] [PULSE=1] tools/monitor-speed-test/kdenlive-headless.sh <project.kdenlive> [pitch 0|1]
#   RAPID=1: quick changes; RAPID=2: long back and forth (~2 min); RAPID=3: fixed speeds (1x 4 s, 1.5x and 2x 10 s
#   each, to measure the continuity with continuity.py); RAPID=4: 1x 4 s, then 1.75x 12 s;
#   PULSE=1: the audio goes through the sound server (PipeWire/Pulse) to a virtual device created for the test
#   (module-null-sink) and is recorded from its monitor, with the timing of a real sound card.
# The project opens at its saved position (kdenlive:sequenceproperties.position). If the media was replaced, delete
# the kdenlive:file_hash/file_size properties of the project, otherwise the clip checker opens an (invisible) dialog.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(realpath "$1")"; PITCH="${2:-0}"
W="$(mktemp -d)"; mkdir -p "$W/config" "$W/data" "$W/cache" "$W/tmp"
cp ~/.config/catavanrc "$W/config/"
sed -i "s/^monitorPlaybackSpeed=.*/monitorPlaybackSpeed=1/; s/^monitorSpeedPreservePitch=.*/monitorSpeedPreservePitch=$([ "$PITCH" = 1 ] && echo true || echo false)/" "$W/config/catavanrc"
cat > "$W/drive.sh" <<DRIVE
#!/bin/bash
source "\${CATAVAN_BUILD_CACHE:-\$HOME/.cache/catavan-build}/env.sh"
export TMPDIR="$W/tmp" XDG_CONFIG_HOME="$W/config" XDG_DATA_HOME="$W/data" XDG_CACHE_HOME="$W/cache"
export QT_QPA_PLATFORM=offscreen LC_ALL=C
if [ "${PULSE:-0}" = 1 ]; then
  export SDL_AUDIODRIVER=pulseaudio PULSE_SINK=kdenlive_vegas_test
  parecord --device=kdenlive_vegas_test.monitor --format=float32le --rate=48000 --channels=2 --raw "$W/audio.raw" &
  RECPID=\$!
else
  export SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE="$W/audio.raw"
fi
catavan "$PROJECT" > "$W/kd.log" 2>&1 &
KPID=\$!
SVC=""; OBJ=""
for i in \$(seq 1 120); do SVC=\$(qdbus6 2>/dev/null | grep -i "com.hexoby.catavan" | head -1 | tr -d " "); [ -n "\$SVC" ] && break; sleep 1; done
for i in \$(seq 1 120); do OBJ=\$(qdbus6 "\$SVC" 2>/dev/null | grep -i "MainWindow" | grep -v "/actions" | head -1); [ -n "\$OBJ" ] && break; sleep 1; done
sleep 25   # project loading
act() { echo "\$(date +%s.%N) \$1" >> "$W/steps.log"; qdbus6 "\$SVC" "\$OBJ" org.kde.KMainWindow.activateAction "\$1" > /dev/null 2>&1; }
if [ "${RAPID:-0}" = 4 ]; then
  act monitor_play; sleep 4
  act monitor_seek_forward; act monitor_seek_forward; act monitor_seek_forward; sleep 12  # 1.75x
elif [ "${RAPID:-0}" = 3 ]; then
  act monitor_play; sleep 4
  act monitor_seek_forward; act monitor_seek_forward; sleep 10                      # 1.5x
  act monitor_seek_forward; act monitor_seek_forward; sleep 10                      # 2x
elif [ "${RAPID:-0}" = 2 ]; then
  # Long back and forth: the reported problem got worse over time
  act monitor_play; sleep 3
  for cycle in \$(seq 1 14); do
    n=\$(( (cycle % 4) + 2 ))
    for i in \$(seq 1 \$n); do act monitor_seek_forward; sleep 0.2; done; sleep 2.5
    for i in \$(seq 1 \$(( n + 2 ))); do act monitor_seek_backward; sleep 0.2; done; sleep 2.5
    for i in 1 2; do act monitor_seek_forward; sleep 0.2; done; sleep 2
  done
  act monitor_pause; sleep 4
elif [ "${RAPID:-0}" = 1 ]; then
  # Many quick changes, forwards and backwards (what degraded the audio)
  act monitor_play; sleep 4
  for i in 1 2 3 4 5 6; do act monitor_seek_forward; sleep 0.15; done; sleep 4      # 2.5x
  for i in 1 2 3 4 5 6 7 8; do act monitor_seek_backward; sleep 0.15; done; sleep 4 # 0.5x
  for i in 1 2 3 4; do act monitor_seek_forward; sleep 0.15; done; sleep 4         # 1.5x
  for i in 1 2 3 4; do act monitor_seek_backward; sleep 0.15; done; sleep 4        # 0.5x
  act monitor_pause; sleep 4                                                        # K: 1x
else
act monitor_play; sleep 8                  # saved speed (1x)
act monitor_seek_forward; sleep 6          # 1.25
act monitor_seek_forward; sleep 6          # 1.50
act monitor_seek_forward; sleep 6          # 1.75
act monitor_seek_forward; sleep 6          # 2.00
act monitor_pause; sleep 5                 # K: 1x
for i in 1 2 3 4 5 6 7 8; do act monitor_seek_backward; done; sleep 6   # J x8: -1x
fi
echo "\$(date +%s.%N) end" >> "$W/steps.log"
qdbus6 "\$SVC" "\$OBJ" org.kde.KMainWindow.activateAction file_quit > /dev/null 2>&1 || true
for i in \$(seq 1 20); do kill -0 \$KPID 2>/dev/null || break; sleep 1; done
kill \$KPID 2>/dev/null || true
[ -n "\${RECPID:-}" ] && kill \$RECPID 2>/dev/null || true
DRIVE
chmod +x "$W/drive.sh"
if [ "${PULSE:-0}" = 1 ]; then
  SINKMOD=$(pactl load-module module-null-sink sink_name=kdenlive_vegas_test rate=48000 channels=2)
  trap 'pactl unload-module '"$SINKMOD"' 2>/dev/null || true' EXIT
fi
dbus-run-session -- "$W/drive.sh" < /dev/null > "$W/dbus.log" 2>&1   # otherwise dbus-daemon keeps the output open
mkdir -p "$W/kd" && mv "$W/audio.raw" "$W/steps.log" "$W/kd/"
python3 "$HERE/kdenlive_analyze.py" "$W" | awk 'NR%2==1'
echo "(files in $W; 'drops' must be 0 and each window a single frequency)"
