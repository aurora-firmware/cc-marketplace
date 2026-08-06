#!/usr/bin/env bash
# Publish drafted release notes to GitHub releases.
#
# Expects a directory containing one <tag>.md file per release tag (e.g.
# 0.5.0.md) and applies each via `gh release edit <tag> --notes-file <file>`.
# Only run this after the drafts have been shown to the user and they've
# confirmed — editing a public release description is visible to everyone
# watching the repo, so it isn't something to do speculatively.
#
# Usage:
#   publish-release-notes.sh <notes-dir> [tag...]
#   (with no tags, publishes every *.md file found in <notes-dir>)
set -euo pipefail

[ "$#" -ge 1 ] || { echo "Usage: $0 <notes-dir> [tag...]" >&2; exit 1; }

dir="$1"; shift

if [ "$#" -eq 0 ]; then
  mapfile -t tags < <(find "$dir" -maxdepth 1 -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort -V)
else
  tags=("$@")
fi

[ "${#tags[@]}" -gt 0 ] || { echo "no *.md notes files found in $dir" >&2; exit 1; }

for tag in "${tags[@]}"; do
  file="$dir/$tag.md"
  if [ ! -f "$file" ]; then
    echo "skip: no notes file for $tag ($file)" >&2
    continue
  fi

  if ! gh release view "$tag" >/dev/null 2>&1; then
    echo "skip: $tag has no existing GitHub release — create one first with" >&2
    echo "      'gh release create $tag' if that's really what you want, this" >&2
    echo "      script only edits existing releases." >&2
    continue
  fi

  echo "=== publishing $tag ==="
  if ! gh release edit "$tag" --notes-file "$file"; then
    status=$?
    echo "FAILED: $tag (exit $status)" >&2
    echo "  If this was a 404, the active 'gh' account likely has read-only" >&2
    echo "  access to this repo. Run 'gh auth status' to see which account is" >&2
    echo "  active, and 'gh auth switch' to pick one with push access." >&2
    exit "$status"
  fi
done
