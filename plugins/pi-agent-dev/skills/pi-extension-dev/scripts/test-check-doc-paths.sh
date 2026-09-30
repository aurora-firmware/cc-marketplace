#!/usr/bin/env bash
# Tests for check-doc-paths.sh. Run: bash test-check-doc-paths.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/check-doc-paths.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

assert() { # name, status (0 = pass)
  if [ "$2" -eq 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

pkg="$tmp/pkg with space"
mkdir -p "$pkg/docs" "$pkg/examples/extensions/some-dir"
printf '{"name": "@earendil-works/pi-coding-agent", "version": "1.2.3"}\n' > "$pkg/package.json"
touch "$pkg/docs/a.md" "$pkg/examples/extensions/a.ts"
export PI_PACKAGE_DIR="$pkg"

# 1. Every cited path exists (file, directory, and #anchor forms).
cat > "$tmp/good.md" <<'MD'
See `docs/a.md#section`, `examples/extensions/a.ts` and `examples/extensions/some-dir/`.
Not checked: `references/decisions.md` and plain docs/missing.md without backticks.
MD
out="$(bash "$script" "$tmp/good.md" 2>&1)"; rc=$?
assert "all present: exit 0" "$rc"
[[ "$out" == *"all cited docs/examples paths exist"* ]]; assert "all present: success message" $?

# 2. A missing path is reported and fails.
cat > "$tmp/bad.md" <<'MD'
See `docs/a.md` and `examples/extensions/gone.ts` and `docs/also-gone.md`.
MD
out="$(bash "$script" "$tmp/bad.md" 2>/dev/null)"; rc=$?
[ "$rc" -eq 1 ]; assert "missing: exit 1" $?
[[ "$out" == *"MISSING: examples/extensions/gone.ts"* ]]; assert "missing: names first path" $?
[[ "$out" == *"MISSING: docs/also-gone.md"* ]]; assert "missing: names second path" $?
[[ "$out" != *"MISSING: docs/a.md"* ]]; assert "missing: does not flag existing path" $?

# 3. Multiple files are all checked.
out="$(bash "$script" "$tmp/good.md" "$tmp/bad.md" 2>/dev/null)"; rc=$?
[ "$rc" -eq 1 ]; assert "multi-file: fails if any file has a missing path" $?

# 4. No arguments is a usage error.
bash "$script" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ]; assert "no args: exit 64" $?

# 5. An unreadable input file is an error, not a silent pass.
out="$(bash "$script" "$tmp/does-not-exist.md" 2>/dev/null)"; rc=$?
[ "$rc" -eq 66 ]; assert "unreadable file: exit 66" $?
[[ "$out" != *"all cited docs/examples paths exist"* ]]; assert "unreadable file: no success message" $?

[ "$failures" -eq 0 ]
