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

make_pkg() { # dir, package-name, with-docs (yes|no), [version]
  mkdir -p "$1"
  printf '{\n\t"name": "%s",\n\t"version": "%s"\n}\n' "$2" "${4:-1.2.3}" > "$1/package.json"
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

# Isolated PATH with a fake `pi` binary (no npm) resolving into a package tree.
make_pi_bin() { # bin-dir, cli.js path the fake pi symlinks to
  mkdir -p "$1"
  for tool in sed head grep realpath readlink dirname; do
    ln -sf "$(command -v "$tool")" "$1/$tool"
  done
  ln -sf "$2" "$1/pi"
}
run_bin() { # bin-dir, cwd, env...
  local bindir="$1" cwd="$2"; shift 2
  (cd "$cwd" && env -i PATH="$bindir" "$@" "$BASH" "$script")
}

# 5. pi found through its binary (symlink into nested dist/bundle/cli.js).
make_pkg "$tmp/bin pkg/pi-coding-agent" "@earendil-works/pi-coding-agent" yes 4.5.6
mkdir -p "$tmp/bin pkg/pi-coding-agent/dist/bundle"
touch "$tmp/bin pkg/pi-coding-agent/dist/bundle/cli.js"
make_pi_bin "$tmp/pibin" "$tmp/bin pkg/pi-coding-agent/dist/bundle/cli.js"
out="$(run_bin "$tmp/pibin" "$tmp/cwd" 2>"$tmp/err")"; rc=$?
assert "pi binary: exit 0" "$rc"
[[ "$out" == *"PACKAGE=$tmp/bin pkg/pi-coding-agent"$'\n'* ]]; assert "pi binary: prints package root" $?
[[ "$out" == *"VERSION=4.5.6"* ]]; assert "pi binary: prints version" $?
[[ "$out" == *"DOCS=$tmp/bin pkg/pi-coding-agent/docs"* ]]; assert "pi binary: prints docs dir" $?

# 6. pi binary resolves into a tree with the old package name: rejected.
make_pkg "$tmp/oldbin/pkg" "@mariozechner/pi-coding-agent" yes
mkdir -p "$tmp/oldbin/pkg/dist/bundle"; touch "$tmp/oldbin/pkg/dist/bundle/cli.js"
make_pi_bin "$tmp/oldpibin" "$tmp/oldbin/pkg/dist/bundle/cli.js"
out="$(run_bin "$tmp/oldpibin" "$tmp/cwd" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 1 ]; assert "pi binary, old name: exit 1" $?

# 7. PWD node_modules wins over the pi binary; differing versions warn on stderr.
make_pkg "$tmp/cwd/node_modules/@earendil-works/pi-coding-agent" "@earendil-works/pi-coding-agent" yes 1.2.3
out="$(run_bin "$tmp/pibin" "$tmp/cwd" 2>"$tmp/err")"; rc=$?
assert "mismatch: exit 0" "$rc"
[[ "$out" == *"VERSION=1.2.3"* ]]; assert "mismatch: chooses project-local package" $?
grep -q "1.2.3" "$tmp/err" && grep -q "4.5.6" "$tmp/err" && grep -qi "warning" "$tmp/err"; assert "mismatch: warning names both versions" $?
grep -qi "using" "$tmp/err"; assert "mismatch: warning says which was chosen" $?

# 8. Same version in both places: no warning.
make_pkg "$tmp/cwd/node_modules/@earendil-works/pi-coding-agent" "@earendil-works/pi-coding-agent" yes 4.5.6
out="$(run_bin "$tmp/pibin" "$tmp/cwd" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 0 ] && [ ! -s "$tmp/err" ]; assert "same version: no warning" $?

[ "$failures" -eq 0 ]
