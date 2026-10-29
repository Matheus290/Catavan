#!/usr/bin/env bash
# make-patch.sh <feature> — writes patches/<feature>.diff, comparing upstream/ with src/ for the files listed in
# patches/<feature>.files (one path per line, relative to src/, e.g. mlt-7.42.0/src/modules/wsola/filter_wsola.cpp),
# then rewrites patches/catavan.patch.
#
# patches/catavan.patch holds every change of src/ against upstream/, binary files (icons) included: setup.sh applies
# it to the downloaded sources to create src/. The <feature>.diff files are for reading and review; they overlap.
#
# make-patch.sh --all   only rewrites patches/catavan.patch
#
# Without an argument, lists the files changed in src/ that belong to no feature (so nothing escapes the patches).
set -euo pipefail
export LC_ALL=C

command -v diff > /dev/null || { echo "diff not found (install diffutils)" >&2; exit 1; }
command -v git > /dev/null || { echo "git not found" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHES="$HERE/patches"
cd "$HERE"

# git diff --no-index names the files upstream/<path> and src/<path>; the patch uses <path> on both sides, applied
# with "git apply -p1" inside src/.
write_full_patch() {
  local out="$PATCHES/catavan.patch"
  git diff --no-index --no-renames --binary upstream src \
    | sed -E -e '/^diff --git /s#(a|b)/(upstream|src)/#\1/#g' \
             -e 's#^--- a/(upstream|src)/#--- a/#' -e 's#^\+\+\+ b/(upstream|src)/#+++ b/#' > "$out" || true
  echo "$out: $(grep -c '^diff --git ' "$out") files"
}

changed_files() {
  diff -rqN upstream src | sed -E 's#^Files upstream/(.*) and src/.* differ$#\1#'
}

if [ $# -eq 0 ]; then
  orphans=0
  while read -r f; do
    if ! grep -qhxF "$f" "$PATCHES"/*.files 2>/dev/null; then
      echo "no feature: $f"
      orphans=1
    fi
  done < <(changed_files)
  [ $orphans -eq 0 ] && echo "Every changed file belongs to a feature."
  exit 0
fi

if [ "$1" = --all ]; then
  write_full_patch
  exit 0
fi

name="$1"
list="$PATCHES/$name.files"
[ -f "$list" ] || { echo "Missing $list" >&2; exit 1; }

out="$PATCHES/$name.diff"
: > "$out"
while read -r f; do
  [ -z "$f" ] || [[ "$f" == \#* ]] && continue
  diff -uN --label "a/$f" --label "b/$f" "upstream/$f" "src/$f" >> "$out" || true
done < "$list"
echo "$out: $(grep -c '^+++ ' "$out") files, +$(grep -c '^+[^+]' "$out")/-$(grep -c '^-[^-]' "$out") lines"
write_full_patch
