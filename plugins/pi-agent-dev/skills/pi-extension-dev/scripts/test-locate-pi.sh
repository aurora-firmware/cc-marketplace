#!/usr/bin/env bash
# Tests for locate-pi.sh. Run: bash test-locate-pi.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/locate-pi.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cwd" "$tmp/bin"
failures=0

assert() { # name, status (0 = pass)
  if [ "$2" -eq 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

make_pkg() { # dir, package-name, with-docs (yes|no)
  mkdir -p "$1"
  printf '{\n\t"name": "%s",\n\t"version": "1.2.3"\n}\n' "$2" > "$1/package.json"
  if [ "$3" = "yes" ]; then mkdir -p "$1/docs" "$1/examples"; fi
}

# Minimal PATH with no npm, so only PI_PACKAGE_DIR and $PWD/node_modules are searched.
for tool in sed head grep; do ln -s "$(command -v "$tool")" "$tmp/bin/$tool"; done
run() { (cd "$tmp/cwd" && env -i PATH="$tmp/bin" "$@" "$BASH" "$script"); }

# 1. Found with docs and examples (path contains a space).
make_pkg "$tmp/ok pkg" "@earendil-works/pi-coding-agent" yes
out="$(run PI_PACKAGE_DIR="$tmp/ok pkg" 2>"$tmp/err")"; rc=$?
assert "found: exit 0" "$rc"
[[ "$out" == *"VERSION=1.2.3"* ]]; assert "found: prints version" $?
[[ "$out" == *"DOCS=$tmp/ok pkg/docs"* ]]; assert "found: prints docs dir with space intact" $?
[[ "$out" == *"EXAMPLES=$tmp/ok pkg/examples"* ]]; assert "found: prints examples dir" $?

# 2. Not found anywhere.
out="$(run PI_PACKAGE_DIR="$tmp/missing" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 1 ]; assert "not found: exit 1" $?
grep -q "not found" "$tmp/err"; assert "not found: stderr says not found" $?
grep -q "github.com/earendil-works/pi" "$tmp/err"; assert "not found: stderr gives fallback URL" $?

# 3. Package present but docs/examples stripped.
make_pkg "$tmp/nodocs" "@earendil-works/pi-coding-agent" no
out="$(run PI_PACKAGE_DIR="$tmp/nodocs" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 2 ]; assert "no docs: exit 2" $?
[[ "$out" == *"PACKAGE=$tmp/nodocs"* ]]; assert "no docs: still prints package" $?
grep -q "github.com/earendil-works/pi" "$tmp/err"; assert "no docs: stderr gives fallback URL" $?

# 4. Old package name is not accepted.
make_pkg "$tmp/old" "@mariozechner/pi-coding-agent" yes
out="$(run PI_PACKAGE_DIR="$tmp/old" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 1 ]; assert "old name: rejected with exit 1" $?

[ "$failures" -eq 0 ]
