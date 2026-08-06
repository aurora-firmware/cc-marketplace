#!/usr/bin/env bash
# List non-merge commit subjects for one or more git tags, scoped to the
# range since each tag's true predecessor in the repository's full tag
# history — not just the previous tag *requested* on the command line.
# This matters because a tag with no published GitHub release (a skipped
# or yanked version) still needs to count as a boundary, otherwise its
# commits get silently merged into the wrong release or double-counted.
#
# Usage:
#   list-tag-commits.sh <tag> [tag...]
#   list-tag-commits.sh --all
#   list-tag-commits.sh --last N
set -euo pipefail

usage() {
  echo "Usage: $0 <tag> [tag...]" >&2
  echo "       $0 --all" >&2
  echo "       $0 --last N" >&2
  exit 1
}

[ "$#" -ge 1 ] || usage

mapfile -t all_tags < <(git tag -l | sort -V)
[ "${#all_tags[@]}" -gt 0 ] || { echo "no tags found in this repo" >&2; exit 1; }

case "$1" in
  --all)
    requested=("${all_tags[@]}")
    ;;
  --last)
    n="${2:-}"
    [[ "$n" =~ ^[0-9]+$ ]] || usage
    start=$(( ${#all_tags[@]} - n ))
    [ "$start" -lt 0 ] && start=0
    requested=("${all_tags[@]:$start}")
    ;;
  *)
    requested=("$@")
    ;;
esac

prev_tag_of() {
  local target="$1" prev=""
  for t in "${all_tags[@]}"; do
    [ "$t" = "$target" ] && { echo "$prev"; return; }
    prev="$t"
  done
}

for tag in "${requested[@]}"; do
  if ! git rev-parse "$tag" >/dev/null 2>&1; then
    echo "warning: tag '$tag' not found in this repo, skipping" >&2
    continue
  fi
  prev="$(prev_tag_of "$tag")"
  echo "=== $tag ==="
  if [ -z "$prev" ]; then
    echo "(first tag — full history reachable from here)"
    git log --no-merges --reverse --pretty=format:'%h %s' "$tag"
  else
    echo "(since $prev)"
    git log --no-merges --reverse --pretty=format:'%h %s' "${prev}..${tag}"
  fi
  echo
  echo
done
