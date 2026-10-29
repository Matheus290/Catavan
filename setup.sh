#!/usr/bin/env bash
# setup.sh — prepares the machine to build Catavan.
# Idempotent: it can be run any number of times.
#   1. detects the distribution and installs the build/runtime dependencies
#   2. makes sure upstream/ and src/ exist: downloads the Kdenlive and MLT tarballs, extracts them into upstream/ and,
#      when src/ is missing, extracts them again into src/ and applies patches/catavan.patch
#   3. creates the build directories outside the source tree
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env
source "$HERE/versions.env"

CACHE="${CATAVAN_BUILD_CACHE:-$HOME/.cache/catavan-build}"
DOWNLOADS="$CACHE/downloads"

log() { printf '\033[1;34m[setup]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[setup]\033[0m %s\n' "$*" >&2; exit 1; }

SUDO=""
[ "$(id -u)" -eq 0 ] || [ -n "${MSYSTEM:-}" ] || SUDO="sudo"

# ---------------------------------------------------------------- dependencies
DEB_PKGS=(
  build-essential cmake ninja-build pkg-config git gettext curl xz-utils extra-cmake-modules
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev qt6-svg-dev
  qt6-multimedia-dev qt6-networkauth-dev qt6-tools-dev qt6-5compat-dev qt6-image-formats-plugins
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts
  qml6-module-qtquick-window qml6-module-qtquick-dialogs qml6-module-qtqml-workerscript
  qml6-module-qtquick-templates qml6-module-qt5compat-graphicaleffects qml6-module-qtmultimedia
  qml6-module-org-kde-kirigami
  libkf6i18n-dev libkf6archive-dev libkf6bookmarks-dev libkf6codecs-dev libkf6coreaddons-dev
  libkf6config-dev libkf6configwidgets-dev libkf6kio-dev libkf6widgetsaddons-dev
  libkf6notifyconfig-dev libkf6newstuff-dev libkf6xmlgui-dev libkf6notifications-dev
  libkf6guiaddons-dev libkf6textwidgets-dev libkf6iconthemes-dev libkf6solid-dev
  libkf6filemetadata-dev libkf6purpose-dev libkf6doctools-dev libkf6crash-dev libkf6dbusaddons-dev
  kf6-breeze-icon-theme breeze
  libkddockwidgets-qt6-dev libopentimelineio-dev libimath-dev
  libavformat-dev libavcodec-dev libavutil-dev libswresample-dev libswscale-dev libavfilter-dev
  libavdevice-dev
  libsdl2-dev libfftw3-dev libexif-dev libfontconfig-dev frei0r-plugins-dev frei0r-plugins
  libgdk-pixbuf-2.0-dev libpango1.0-dev libjack-jackd2-dev libxml2-dev liblilv-dev ladspa-sdk
  libmovit-dev libebur128-dev libplacebo-dev librubberband-dev libsamplerate0-dev libsox-dev
  libvidstab-dev libvorbis-dev libtheora-dev libx11-dev libgl-dev libglib2.0-dev libsndfile1-dev
  librtaudio-dev libpulse-dev libasound2-dev
  ffmpeg mediainfo
  # Optional MLT modules (build.sh EXTRA_MODULES): OpenCV for the motion tracker; Glaxnimate only needs Qt
  libopencv-contrib-dev
)

install_deb() {
  local missing=()
  for p in "${DEB_PKGS[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    log "All dependencies are already installed."
    return
  fi
  log "Installing ${#missing[@]} packages: ${missing[*]}"
  $SUDO apt-get update
  $SUDO apt-get install -y --no-install-recommends "${missing[@]}"
}

install_fedora() {
  # Fedora packages kdenlive and mlt; builddep brings exactly what they use.
  $SUDO dnf install -y dnf-plugins-core cmake ninja-build gcc-c++ git curl xz \
    extra-cmake-modules ffmpeg-free mediainfo opencv-devel
  $SUDO dnf builddep -y mlt kdenlive
}

install_arch() {
  local deps
  deps=$(LC_ALL=C pacman -Si kdenlive mlt | awk -F': ' '/^(Depends On|Make Depends)/{print $2}' \
    | tr ' ' '\n' | grep -v -e '^None$' -e '^mlt' -e '^$' | sed 's/[<>=].*//' | sort -u)
  # shellcheck disable=SC2086
  $SUDO pacman -S --needed --noconfirm base-devel cmake ninja git curl extra-cmake-modules opencv $deps
}

install_suse() {
  $SUDO zypper --non-interactive install -t pattern devel_basis
  $SUDO zypper --non-interactive install cmake ninja git curl extra-cmake-modules opencv-devel
  $SUDO zypper --non-interactive source-install --build-deps-only mlt kdenlive
}

# Windows: MSYS2, UCRT64 environment. Packages kdenlive and mlt; these are their dependencies plus the build tools.
MSYS2_PKGS=(
  toolchain cmake ninja pkgconf extra-cmake-modules gettext-tools python
  qt6-base qt6-declarative qt6-svg qt6-multimedia qt6-networkauth qt6-tools qt6-5compat qt6-imageformats
  qt6-shadertools qt6-translations
  karchive kbookmarks kcodecs kcolorscheme kcompletion kconfig kconfigwidgets kcoreaddons kcrash kdbusaddons
  kddockwidgets kfilemetadata kguiaddons ki18n kiconthemes kio kitemviews knewstuff knotifications knotifyconfig
  ktextwidgets kwidgetsaddons kxmlgui purpose solid kdoctools kirigami kdeclarative qqc2-desktop-style
  breeze-icons breeze
  opentimelineio imath shared-mime-info ffmpeg SDL2 fftw libsamplerate rubberband sox libebur128 vid.stab
  libvorbis gdk-pixbuf2 pango fontconfig libxml2 frei0r-plugins ladspa-sdk lilv libexif dlfcn rtaudio libsndfile
  mediainfo
  opencv rnnoise
  # icotool: the icon embedded in catavan.exe (without it ECM builds the executable with no icon); the installer
  icoutils nsis
)

install_msys2() {
  [ "$MSYSTEM" = UCRT64 ] || die "Run setup.sh from the MSYS2 UCRT64 shell (MSYSTEM is $MSYSTEM)."
  pacman -S --needed --noconfirm curl tar xz diffutils patch git "${MSYS2_PKGS[@]/#/$MINGW_PACKAGE_PREFIX-}"
}

if [ -n "${MSYSTEM:-}" ]; then
  install_msys2
else
. /etc/os-release
ids=" ${ID:-} ${ID_LIKE:-} "
case "$ids" in
  *" debian "*|*" ubuntu "*) install_deb ;;
  *" fedora "*|*" rhel "*)   install_fedora ;;
  *" arch "*)                install_arch ;;
  *" suse "*|*" opensuse "*) install_suse ;;
  *) die "Unsupported distribution: ${PRETTY_NAME:-unknown}. Install the dependencies by hand (see DEB_PKGS)." ;;
esac
fi

# ---------------------------------------------------------------- sources
fetch() { # url file sha256(optional)
  local url="$1" file="$DOWNLOADS/$2" sum="${3:-}"
  mkdir -p "$DOWNLOADS"
  if [ ! -f "$file" ]; then
    log "Downloading $2"
    curl -fSL --retry 3 -o "$file.part" "$url"
    mv "$file.part" "$file"
  fi
  if [ -n "$sum" ]; then
    echo "$sum  $file" | sha256sum -c --quiet - || die "Invalid checksum: $file"
  fi
}

unpack() { # file dest-dir folder-name
  local file="$DOWNLOADS/$1" dest="$2" name="$3"
  log "Extracting $1 into ${dest#"$HERE"/}"
  mkdir -p "$dest"
  tar -xf "$file" -C "$dest"
  # The tarballs carry .git pointers of submodules; no .git files in the source tree.
  find "$dest/$name" -name .git -type f -delete
}

fetch "$KDENLIVE_URL" "$KDENLIVE_TARBALL" "$KDENLIVE_SHA256"
fetch "$MLT_URL" "$MLT_TARBALL" "$MLT_SHA256"
# Built by build.sh only when the system has no rnnoise package (Debian/Ubuntu)
fetch "$RNNOISE_URL" "$RNNOISE_TARBALL" "$RNNOISE_SHA256"
# upstream/: the original sources, which tools/make-patch.sh compares with src/
[ -d "$HERE/upstream/kdenlive-$KDENLIVE_VERSION" ] || unpack "$KDENLIVE_TARBALL" "$HERE/upstream" "kdenlive-$KDENLIVE_VERSION"
[ -d "$HERE/upstream/mlt-$MLT_VERSION" ] || unpack "$MLT_TARBALL" "$HERE/upstream" "mlt-$MLT_VERSION"
# src/: the sources with the Catavan changes. Created once; an existing src/ (work in progress) is never touched.
if [ ! -d "$HERE/src" ]; then
  rm -rf "$HERE/src.part"
  unpack "$KDENLIVE_TARBALL" "$HERE/src.part" "kdenlive-$KDENLIVE_VERSION"
  unpack "$MLT_TARBALL" "$HERE/src.part" "mlt-$MLT_VERSION"
  log "Applying patches/catavan.patch"
  # GIT_CEILING_DIRECTORIES: inside a git repository, git apply takes the paths as relative to its root
  (cd "$HERE/src.part" && GIT_CEILING_DIRECTORIES="$HERE" git apply -p1 --whitespace=nowarn "$HERE/patches/catavan.patch")
  mv "$HERE/src.part" "$HERE/src"
fi

# Syncthing (used by the author) does not sync .stignore: the parent folder's .stignore includes the rules of
# stignore.txt, which are synced.
STIGNORE="$HERE/../.stignore"
INCLUDE_LINE="#include $(basename "$HERE")/stignore.txt"
if ! grep -qxF "$INCLUDE_LINE" "$STIGNORE" 2>/dev/null; then
  log "Adding the rules to the parent folder .stignore"
  echo "$INCLUDE_LINE" >> "$STIGNORE"
fi

mkdir -p "$CACHE/build" "$CACHE/install"
log "Done. Run ./build.sh to build and start Catavan."
