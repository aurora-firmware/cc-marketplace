#!/usr/bin/env bash
# Verify that docs/, examples/ and dist/ paths cited in markdown files exist in the installed pi package.
# Usage: check-doc-paths.sh <file.md>...   (package resolved by locate-pi.sh; honours PI_PACKAGE_DIR)
# Exit 0: all present. Exit 1: some missing. Exit 64: usage. Exit 66: unreadable file. Other: locate-pi.sh failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <file.md>..." >&2
  exit 64
fi

info="$(bash "$here/locate-pi.sh")"
pkg="$(printf '%s\n' "$info" | sed -n 's/^PACKAGE=//p')"

missing=0
for file in "$@"; do
  [ -r "$file" ] || { echo "cannot read $file" >&2; exit 66; }
  while IFS= read -r cited; do
    if [ ! -e "$pkg/$cited" ]; then
      echo "MISSING: $cited (cited in $file)"
      missing=$((missing + 1))
    fi
  done < <(grep -oE '`(docs|examples|dist)/[^`# ]+' "$file" | tr -d '`' | sort -u || true)
done

if [ "$missing" -gt 0 ]; then
  echo "$missing cited path(s) missing from $pkg" >&2
  exit 1
fi
echo "all cited docs/examples paths exist in $pkg"
