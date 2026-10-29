#!/usr/bin/env bash
# collect.sh <AppDir> <linuxdeploy> — run by build.sh inside the Flatpak build sandbox (/app = Catavan build,
# /usr = KDE SDK). Copies /app, the Qt plugins, QML modules and translations of the SDK into the AppDir, then lets
# linuxdeploy copy every library they need (except the ones every system has, like glibc and the GPU drivers).
set -euo pipefail

APPDIR="$1"
LINUXDEPLOY="$2"
USR="$APPDIR/usr"
SDK_LIB=/usr/lib/x86_64-linux-gnu

mkdir -p "$USR"
cp -a /app/. "$USR/"
# The Flatpak build renamed the icon to the app ID (rename-icon); the desktop file uses that name too
# share/locale/<lang> are links into share/runtime/locale (the Flatpak locale extension): copy the files themselves
rm -rf "$USR/extensions" "$USR/manifest.json" "$USR/share/runtime" "$USR/share/locale" "$USR/lib/debug"
cp -rL /app/share/locale "$USR/share/locale"

# Qt plugins and QML modules of the SDK (paths set in qt.conf). Developer tools and Plasma are left out.
mkdir -p "$USR/plugins" "$USR/qml" "$USR/translations"
cp -a /usr/lib/plugins/. "$USR/plugins/"
rm -rf "$USR/plugins/"{designer,qmllint,qmlls,qmltooling,plasma,kcm_trash.so,kstyle_config}
cp -a /usr/lib/qml/. "$USR/qml/"
cp -a /usr/translations/qt*.qm "$USR/translations/"

# KDE Frameworks translations (menus, dialogs), resolved from the locale extension of the SDK.
for dir in /usr/share/locale/*/LC_MESSAGES; do
  lang="$(basename "$(dirname "$dir")")"
  for mo in "$dir"/*6.mo "$dir"/kirigami6*.mo; do
    [ -e "$mo" ] || continue
    mkdir -p "$USR/share/locale/$lang/LC_MESSAGES"
    cp -L "$mo" "$USR/share/locale/$lang/LC_MESSAGES/"
  done
done

cat > "$USR/bin/qt.conf" <<'EOF'
[Paths]
Prefix = ..
Plugins = plugins
QmlImports = qml
Qml2Imports = qml
Translations = translations
EOF

# Every directory with ELF files whose dependencies must be in the AppDir.
deps=()
while read -r d; do
  deps+=(--deploy-deps-only="$d")
done < <(find "$USR/lib" "$USR/plugins" "$USR/qml" -type f -name '*.so*' -printf '%h\n' | sort -u)

executables=()
for exe in catavan catavan_render melt ffmpeg ffprobe ffplay; do
  [ -x "$USR/bin/$exe" ] && executables+=(--executable="$USR/bin/$exe")
done

"$LINUXDEPLOY" --appimage-extract-and-run --appdir "$APPDIR" \
  "${executables[@]}" "${deps[@]}" \
  --desktop-file="$USR/share/applications/com.hexoby.Catavan.desktop" \
  --icon-file="$USR/share/icons/hicolor/256x256/apps/com.hexoby.Catavan.png"
