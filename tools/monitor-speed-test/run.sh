#!/usr/bin/env bash
# run.sh — tests the MLT monitorspeed filter outside Catavan: plays a WAV of frequency steps
# (300/600/900/1200 Hz, 2 s each) in a tractor at several speeds and analyzes the output
# (dominant frequency over time and silent 10 ms blocks).
# Usage: tools/monitor-speed-test/run.sh   (needs ./build.sh mlt first; python3 with numpy)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
I="${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}/install"
OUT="$(mktemp -d)"
source "${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}/env.sh"
export LC_ALL=C
g++ -O1 -o "$OUT/play" "$HERE/play.cpp" -I"$I/include/mlt-7" -I"$I/include/mlt-7/mlt++" -L"$I/lib" -lmlt++-7 -lmlt-7 -Wl,-rpath,"$I/lib"
python3 - "$OUT" <<'PY'
import numpy as np, wave, sys
sr=48000; out=sys.argv[1]
t=np.arange(sr*8)/sr
f=np.where(t<2,300,np.where(t<4,600,np.where(t<6,900,1200)))
x=(0.5*np.sin(2*np.pi*np.cumsum(f)/sr)*32767).astype(np.int16)
w=wave.open(out+"/steps.wav","wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr); w.writeframes(np.stack([x,x],1).ravel().tobytes()); w.close()
y=(0.3*np.sin(2*np.pi*5000*np.arange(sr*16)/sr)*32767).astype(np.int16)
w=wave.open(out+"/tone5k.wav","wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr); w.writeframes(np.stack([y,y],1).ravel().tobytes()); w.close()
PY
cd "$OUT"
for sp in 0.5 1 1.25 1.5 2 3; do for pp in 0 1; do ./play single steps.wav $sp $pp 100 r_single_${sp}_${pp}.f32 2>/dev/null; done; done
./play mix steps.wav 2 0 100 r_mix_2_0.f32 tone5k.wav 2>/dev/null
./play timewarp steps.wav 2 0 50 r_tw_2_0.f32 2>/dev/null
python3 "$HERE/analyze.py" r_*.f32
echo "(without pitch (_0) the frequencies are multiplied by the speed; with pitch (_1) they stay 300/600/900/1200 Hz;"
echo " the steps change every 2/speed s; at 3x the silence from 2.7 s on is the end of the 8 s WAV)"
# Through the real sdl2_audio consumer (SDL "disk" driver records what would be heard): catches consumer-side
# problems (stalls, frames whose audio is replaced) that the direct test above cannot see
g++ -O1 -o "$OUT/consumer" "$HERE/consumer.cpp" -I"$I/include/mlt-7" -I"$I/include/mlt-7/mlt++" -L"$I/lib" -lmlt++-7 -lmlt-7 -Wl,-rpath,"$I/lib"
for cfg in "0.5 0" "0.75 1" "1.6 0" "1.6 1" "2 0" "-1.5 0"; do
    set -- $cfg
    SDL_AUDIODRIVER=disk SDL_DISKAUDIOFILE="c_$1_$2.raw" ./consumer steps.wav "$1" "$2" 3 >/dev/null 2>&1
done
python3 "$HERE/disk_analyze.py" c_*.raw
echo "(real consumer: 'drops' must be 0 and each window a single frequency; negative speeds play backwards with the same pitch)"
rm -rf "$OUT"
