#!/usr/bin/env bash
# packaging/appimage/build.sh — builds the Catavan AppImage from the Flatpak build.
#
# Run packaging/flatpak/build.sh first: the AppImage takes /app (MLT, FFmpeg, Catavan and their dependencies) from that
# build and the Qt/KDE Frameworks libraries from the KDE SDK it was built with, so both packages carry the same
# binaries. The AppImage needs the glibc of that runtime or newer (2.42, KDE runtime 6.11).
#
#   packaging/appimage/build.sh   writes $CACHE/packages/Catavan-<version>-x86_64.AppImage
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../../versions.env
source "$ROOT/versions.env"

CACHE="$(realpath -m "${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}")"
FLATPAK_BUILD="$CACHE/flatpak/build"
WORK="$CACHE/appimage"
APPDIR="$WORK/Catavan.AppDir"
TOOLS="$WORK/tools"
VERSION="$(sed -nE 's/^set\(CATAVAN_VERSION "([^"]+)"\)/\1/p' "$ROOT/src/kdenlive-$KDENLIVE_VERSION/CMakeLists.txt")"
OUT="$CACHE/packages/Catavan-$VERSION-x86_64.AppImage"

log() { printf '\033[1;32m[appimage]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[appimage]\033[0m %s\n' "$*" >&2; exit 1; }

[ -x "$FLATPAK_BUILD/files/bin/catavan" ] || die "No Flatpak build in $FLATPAK_BUILD; run packaging/flatpak/build.sh first."

mkdir -p "$TOOLS" "$CACHE/packages"
for tool in linuxdeploy/linuxdeploy appimage/appimagetool; do
  name="${tool#*/}-x86_64.AppImage"
  if [ ! -x "$TOOLS/$name" ]; then
    case "$tool" in
      linuxdeploy/*) url="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/$name" ;;
      appimage/*)    url="https://github.com/AppImage/appimagetool/releases/download/continuous/$name" ;;
    esac
    log "Downloading $name"
    curl -fSL --retry 3 -o "$TOOLS/$name.part" "$url"
    chmod +x "$TOOLS/$name.part"
    mv "$TOOLS/$name.part" "$TOOLS/$name"
  fi
done

rm -rf "$APPDIR"
mkdir -p "$APPDIR"

# Inside the build sandbox: /app is the Flatpak build, /usr the KDE SDK.
log "Collecting files in the Flatpak build sandbox"
flatpak build --filesystem="$WORK" --filesystem="$HERE" "$FLATPAK_BUILD" \
  bash "$HERE/collect.sh" "$APPDIR" "$TOOLS/linuxdeploy-x86_64.AppImage"

install -m 755 "$HERE/AppRun" "$APPDIR/AppRun"

log "Writing $OUT"
rm -f "$OUT"
ARCH=x86_64 "$TOOLS/appimagetool-x86_64.AppImage" --appimage-extract-and-run --no-appstream "$APPDIR" "$OUT"
log "Done: $OUT"
