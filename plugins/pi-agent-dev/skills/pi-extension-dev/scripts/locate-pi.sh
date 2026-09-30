#!/usr/bin/env bash
# Locate the installed pi coding-agent package and its docs/examples.
# Prints KEY=value lines. Exit 0: found with docs+examples.
# Exit 1: not found. Exit 2: found but docs/ or examples/ missing.
# Search order: $PI_PACKAGE_DIR, $PWD/node_modules, the package containing the
# running `pi` binary (walk up from its resolved path), then `npm root -g`.
set -euo pipefail

PKG_NAME="@earendil-works/pi-coding-agent"
FALLBACK_URL="https://github.com/earendil-works/pi/tree/main/packages/coding-agent"

candidates=()
if [ -n "${PI_PACKAGE_DIR:-}" ]; then
  candidates+=("$PI_PACKAGE_DIR")
fi
candidates+=("$PWD/node_modules/$PKG_NAME")

pkg_version() { sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$1/package.json" | head -n 1; }
is_pi_pkg() { [ -f "$1/package.json" ] && grep -q "\"name\": *\"$PKG_NAME\"" "$1/package.json"; }

# Candidate from the running pi binary (covers pi's own installer, pnpm, bun, volta, ...).
pi_dir=""
if pi_bin="$(command -v pi 2>/dev/null)" && [ -n "$pi_bin" ]; then
  pi_real=""
  if command -v realpath >/dev/null 2>&1; then
    pi_real="$(realpath "$pi_bin" 2>/dev/null || true)"
  elif command -v readlink >/dev/null 2>&1; then
    pi_real="$(readlink -f "$pi_bin" 2>/dev/null || true)"
  fi
  if [ -n "$pi_real" ]; then
    walk="$(dirname "$pi_real")"
    while :; do
      if is_pi_pkg "$walk"; then pi_dir="$walk"; break; fi
      parent="$(dirname "$walk")"
      [ "$parent" = "$walk" ] && break
      walk="$parent"
    done
  fi
fi
[ -n "$pi_dir" ] && candidates+=("$pi_dir")

if command -v npm >/dev/null 2>&1; then
  global_root="$(npm root -g 2>/dev/null || true)"
  if [ -n "$global_root" ]; then
    candidates+=("$global_root/$PKG_NAME")
  fi
fi

for dir in "${candidates[@]}"; do
  is_pi_pkg "$dir" || continue
  version="$(pkg_version "$dir")"
  if [ "$dir" = "$PWD/node_modules/$PKG_NAME" ] && [ -n "$pi_dir" ] \
    && [ "$(cd "$pi_dir" && pwd -P)" != "$(cd "$dir" && pwd -P)" ]; then
    pi_version="$(pkg_version "$pi_dir")"
    if [ "$pi_version" != "$version" ]; then
      echo "warning: project-local pi $version ($dir) differs from the running pi $pi_version ($pi_dir); using the project-local one (first in search order)." >&2
    fi
  fi
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
