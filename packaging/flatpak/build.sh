#!/usr/bin/env bash
# packaging/flatpak/build.sh — builds the Catavan Flatpak and exports a single-file bundle.
#
#   packaging/flatpak/build.sh            builds and writes $CACHE/packages/Catavan-<version>-x86_64.flatpak
#   packaging/flatpak/build.sh --install  also installs it for the current user (flatpak run com.hexoby.Catavan)
#
# The manifest (com.hexoby.Catavan.json) follows the Flathub manifest of Kdenlive 26.08.2; MLT and Catavan come from
# src/ (run ./setup.sh first). The first build compiles every dependency (FFmpeg, OpenCV, x265...) and takes hours;
# flatpak-builder caches each module, so later builds only redo what changed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../../versions.env
source "$ROOT/versions.env"

CACHE="$(realpath -m "${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}")"
WORK="$CACHE/flatpak"
APP_ID=com.hexoby.Catavan
VERSION="$(sed -nE 's/^set\(CATAVAN_VERSION "([^"]+)"\)/\1/p' "$ROOT/src/kdenlive-$KDENLIVE_VERSION/CMakeLists.txt")"
BUNDLE="$CACHE/packages/Catavan-$VERSION-$(uname -m).flatpak"

log() { printf '\033[1;32m[flatpak]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[flatpak]\033[0m %s\n' "$*" >&2; exit 1; }

install=0
[ "${1:-}" = --install ] && install=1

command -v flatpak-builder > /dev/null || die "flatpak-builder not found (sudo apt install flatpak-builder)"
[ -d "$ROOT/src/kdenlive-$KDENLIVE_VERSION" ] || die "Sources missing; run ./setup.sh first."

flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
mkdir -p "$WORK" "$CACHE/packages"

log "Building $APP_ID $VERSION (state in $WORK)"
flatpak-builder --user --install-deps-from=flathub --force-clean --ccache \
  --state-dir="$WORK/state" --repo="$WORK/repo" \
  "$WORK/build" "$HERE/$APP_ID.json"

log "Writing $BUNDLE"
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  "$WORK/repo" "$BUNDLE" "$APP_ID" stable

if [ "$install" = 1 ]; then
  flatpak --user install -y --reinstall "$BUNDLE"
fi
log "Done: $BUNDLE"
