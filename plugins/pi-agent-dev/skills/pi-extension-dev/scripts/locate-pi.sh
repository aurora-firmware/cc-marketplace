#!/usr/bin/env bash
# Locate the installed pi coding-agent package and its docs/examples.
# Prints KEY=value lines. Exit 0: found with docs+examples.
# Exit 1: not found. Exit 2: found but docs/ or examples/ missing.
set -euo pipefail

PKG_NAME="@earendil-works/pi-coding-agent"
FALLBACK_URL="https://github.com/earendil-works/pi/tree/main/packages/coding-agent"

candidates=()
if [ -n "${PI_PACKAGE_DIR:-}" ]; then
  candidates+=("$PI_PACKAGE_DIR")
fi
candidates+=("$PWD/node_modules/$PKG_NAME")
if command -v npm >/dev/null 2>&1; then
  global_root="$(npm root -g 2>/dev/null || true)"
  if [ -n "$global_root" ]; then
    candidates+=("$global_root/$PKG_NAME")
  fi
fi

for dir in "${candidates[@]}"; do
  [ -f "$dir/package.json" ] || continue
  grep -q "\"name\": *\"$PKG_NAME\"" "$dir/package.json" || continue
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)"
  echo "PACKAGE=$dir"
  echo "VERSION=$version"
  if [ -d "$dir/docs" ] && [ -d "$dir/examples" ]; then
    echo "DOCS=$dir/docs"
    echo "EXAMPLES=$dir/examples"
    exit 0
  fi
  echo "warning: $dir has no docs/ or examples/; use the upstream fallback: $FALLBACK_URL" >&2
  exit 2
done

echo "pi package $PKG_NAME not found (searched: ${candidates[*]}). The older @mariozechner/pi-coding-agent name is not supported. Fall back to $FALLBACK_URL" >&2
exit 1
