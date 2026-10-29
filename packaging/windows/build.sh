#!/usr/bin/env bash
# packaging/windows/build.sh — builds the portable Windows package of Catavan (a .zip) from the MSYS2 build.
#
# Run from the MSYS2 UCRT64 shell after ./build.sh (the package takes MLT and Catavan from $CACHE/install and Qt, the
# KDE Frameworks, FFmpeg and every other DLL from MSYS2). The folder runs without MSYS2: Qt finds its plugins and QML
# modules through bin/qt.conf, MLT finds lib/mlt and share/mlt relative to bin/, and the KDE data stays in bin/data.
#
#   packaging/windows/build.sh   writes $CACHE/packages/Catavan-<version>-windows-x86_64.zip and, from the same folder,
#                                the installer Catavan-<version>-windows-x86_64-setup.exe (catavan.nsi)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=../../versions.env
source "$ROOT/versions.env"

log() { printf '\033[1;32m[windows]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[windows]\033[0m %s\n' "$*" >&2; exit 1; }

[ "${MSYSTEM:-}" = UCRT64 ] || die "Run from the MSYS2 UCRT64 shell (MSYSTEM is ${MSYSTEM:-unset})."

CACHE="$(realpath -m "${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}")"
PREFIX="$CACHE/install"
SYS="$MINGW_PREFIX"
VERSION="$(sed -nE 's/^set\(CATAVAN_VERSION "([^"]+)"\)/\1/p' "$ROOT/src/kdenlive-$KDENLIVE_VERSION/CMakeLists.txt")"
NAME="Catavan-$VERSION-windows-x86_64"
WORK="$CACHE/windows"
DIR="$WORK/$NAME"
OUT="$CACHE/packages/$NAME.zip"

[ -f "$PREFIX/bin/catavan.exe" ] || die "Catavan is not built in $PREFIX; run ./build.sh first."

rm -rf "$DIR"
mkdir -p "$DIR/bin" "$DIR/lib" "$DIR/share" "$CACHE/packages"

log "Copying Catavan and MLT"
cp "$PREFIX"/bin/{catavan,catavan_render,melt}.exe "$PREFIX"/bin/*.dll "$DIR/bin/"
cp -r "$PREFIX/lib/mlt" "$PREFIX/lib/frei0r-1" "$DIR/lib/"
cp -r "$PREFIX/share/mlt" "$DIR/share/"
# The build is RelWithDebInfo: the debug information would make the package several times larger
find "$DIR/bin" "$DIR/lib/mlt" -maxdepth 1 \( -name '*.exe' -o -name '*.dll' \) -exec strip --strip-debug {} +

log "Copying the tools Catavan calls"
# FFmpeg (proxies, transcoding, media information), MediaInfo (camera metadata), the KIO worker (file operations)
cp "$SYS"/bin/{ffmpeg,ffprobe,ffplay,mediainfo,kioworker}.exe "$DIR/bin/"
# mediainfo.exe loads its library at run time, so the import walk below does not see it
cp "$SYS/bin/libmediainfo-0.dll" "$DIR/bin/"

log "Copying the Qt plugins, QML modules and translations"
mkdir -p "$DIR/lib/plugins" "$DIR/lib/qml" "$DIR/translations"
cp -r "$SYS/share/qt6/plugins/." "$DIR/lib/plugins/"
# Developer tools and SQL drivers are not used at run time
rm -rf "$DIR/lib/plugins/"{designer,qmllint,qmlls,qmltooling,sqldrivers}
cp -r "$SYS/share/qt6/qml/." "$DIR/lib/qml/"
# Qt's test modules carry build leftovers whose long paths break extraction near the 260-character limit
rm -rf "$DIR/lib/qml/Qt/test" "$DIR/lib/qml/QtTest"
find "$DIR/lib/qml" -name '*.obj' -delete
cp -r "$PREFIX/lib/plugins/." "$DIR/lib/plugins/"
cp -r "$PREFIX/lib/qml/." "$DIR/lib/qml/"
cp "$SYS"/share/qt6/translations/qt*.qm "$DIR/translations/"
cat > "$DIR/bin/qt.conf" <<'EOF'
[Paths]
Prefix = ..
Plugins = lib/plugins
QmlImports = lib/qml
Qml2Imports = lib/qml
Translations = translations
EOF

log "Copying the KDE data (icons, color schemes, translations)"
# Qt looks for the data in bin/data, where the MSYS2 KDE packages install it
mkdir -p "$DIR/bin/data/icons"
cp -r "$SYS/bin/data/icons/"{breeze,hicolor} "$DIR/bin/data/icons/"
cp -r "$SYS/bin/data/"{color-schemes,icontheme.rcc,kf6,kstyle,locale,qlogging-categories6} "$DIR/bin/data/"
cp -r "$PREFIX/bin/data/." "$DIR/bin/data/"
# Fontconfig (MLT text and Pango modules) looks for its configuration in ../etc/fonts relative to its DLL
mkdir -p "$DIR/etc"
cp -r "$SYS/etc/fonts" "$DIR/etc/"

log "Copying the DLLs they depend on"
# Walks the imports of every executable and module until no new DLL from MSYS2 appears. DLLs that are not in MSYS2
# (Windows system DLLs) are left out.
declare -A seen=()
queue=()
while IFS= read -r -d '' f; do queue+=("$f"); done < <(find "$DIR" -type f \( -name '*.exe' -o -name '*.dll' \) -print0)
while [ ${#queue[@]} -gt 0 ]; do
  f="${queue[0]}"; queue=("${queue[@]:1}")
  while read -r dll; do
    key="${dll,,}"
    [ -z "${seen[$key]:-}" ] || continue
    seen[$key]=1
    [ -f "$DIR/bin/$dll" ] && continue
    [ -f "$SYS/bin/$dll" ] || continue
    cp "$SYS/bin/$dll" "$DIR/bin/"
    queue+=("$DIR/bin/$dll")
  done < <(objdump -p "$f" | sed -nE 's/^\s*DLL Name: (.+)\r?$/\1/p')
done

# Launcher at the top of the folder, so nobody has to look for the executable in bin/
printf '@echo off\r\nstart "" "%%~dp0bin\\catavan.exe" %%*\r\n' > "$DIR/Catavan.cmd"
cp "$ROOT/LICENSE" "$DIR/LICENSE.txt"

log "Writing $OUT"
rm -f "$OUT"
(cd "$WORK" && bsdtar -a -cf "$OUT" "$NAME")
(cd "$CACHE/packages" && sha256sum "$NAME.zip" > "$NAME.zip.sha256")
log "Done: $OUT ($(du -h "$OUT" | cut -f1))"

# Installer (NSIS): the same folder, installed into Program Files with shortcuts and an uninstaller
SETUP="$CACHE/packages/$NAME-setup.exe"
log "Writing $SETUP"
rm -f "$SETUP"
makensis -V2 -DVERSION="$VERSION" -DSOURCE="$(cygpath -w "$DIR")" -DOUTFILE="$(cygpath -w "$SETUP")" \
  -DICON="$(cygpath -w "$ROOT/src/kdenlive-$KDENLIVE_VERSION/data/icons/catavan.ico")" "$(cygpath -w "$HERE/catavan.nsi")"
(cd "$CACHE/packages" && sha256sum "$NAME-setup.exe" > "$NAME-setup.exe.sha256")
log "Done: $SETUP ($(du -h "$SETUP" | cut -f1))"
