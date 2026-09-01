---
name: release
description: >-
  End-to-end workflow for cutting a tagged version release when a CI
  pipeline builds and publishes the release from the pushed tag: verify the
  working tree and release branch are ready, fast-forward the release
  branch, decide the semantic-version bump (major / minor / patch, with the
  pre-1.0 rule), push a tag that matches the repo's existing tag
  convention, watch the release workflow run to completion, verify the
  GitHub Release and the assets the workflow should have attached, and — if
  the pipeline fails or publishes nothing — triage the run and file a
  GitHub issue instead of leaving a half-published release. On success,
  hands off to the changelog skill to replace CI's auto-generated notes
  with proper release notes. Use whenever the user asks to release, cut a
  release, ship a version, tag a release, do a release, bump the version
  and publish, or "push the release tag" — for any repo whose releases are
  produced by a tag-triggered GitHub Actions workflow. Not for manually
  hand-built releases with no CI pipeline (use gh-cli's release-mgmt
  reference directly), and not for writing release notes on their own
  (that's the changelog skill). Defers to gh-cli for exact `gh` command
  syntax, to new-issue for the failure issue, and to changelog for the
  notes.
---

# release

Cut a new version release for a repo whose releases are built and published by CI: you push a
semver tag, a GitHub Actions workflow triggered by that tag builds the artifacts and creates the
GitHub Release. This skill covers the parts that need judgement and verification — choosing the
version, pushing a tag in the right format, confirming the pipeline actually produced a
*complete* Release, handling a failed pipeline, and getting proper release notes onto the
Release.

For exact `gh` command syntax at every step, use the `gh-cli` skill — its
`references/actions-ci.md` (watching runs) and `references/release-mgmt.md` (releases and
assets) in particular. This skill deliberately doesn't repeat that. For the release notes
themselves it hands off to `changelog`; for filing an issue when the pipeline breaks, to
`new-issue`.

**Scope check first:** this workflow assumes a *tag-triggered CI pipeline* does the building and
publishing. Confirm one exists — `gh workflow list`, or look for `on: push: tags:` in
`.github/workflows/`. If releases here are hand-built with `gh release create` and manual asset
uploads, this skill doesn't apply — use `gh-cli`'s `release-mgmt` reference directly.

## Step 1 — Learn this repo's release conventions

Don't assume; check. Look at the project's own docs first — `CONTRIBUTING.md`, `RELEASING.md`,
`CLAUDE.md` / `AGENTS.md`, a `git-conventions` skill in `.claude/skills/`.

Then read the facts out of git and the workflow:

```bash
git fetch --all --tags --prune
git tag --sort=-v:refname | head -10                          # existing version numbers
git cat-file -t "$(git tag --sort=-v:refname | head -1)"      # 'commit' = lightweight, 'tag' = annotated
```

Note:

- **Tag prefix** — `v1.2.3` or bare `1.2.3`? Match it exactly.
- **Tag object** — lightweight or annotated? Match the majority of recent tags.
- **Release branch** — the branch releases are tagged from. Usually the default branch; some
  projects tag from a `release/*` branch or a dedicated integration branch.
- **Release workflow** — which workflow file runs on tag push, and what its release step is
  supposed to attach. Read it, so Step 7 knows what "complete" looks like.

## Step 2 — Preconditions

Stop and report if any of these fail; a release is public and awkward to unwind.

- **Clean working tree** — `git status --porcelain` empty.
- **`gh` write access** — `gh auth status` shows an account that can write to this repo (needed
  for the changelog publish and any issue-filing).
- **Current branch noted** — you return to it in Step 10; don't release from a detached HEAD.
- **Release branch is ready** — it already contains every commit this release should ship. If
  the project integrates work on a *different* branch (e.g. `dev-agent`, `develop`) and merges
  to the release branch by PR, check the release branch isn't missing anything:
  `git rev-list --count origin/<release-branch>..origin/<integration-branch>`. Non-zero means
  the integration branch is ahead — **decide:** is that work part of this release? If yes, stop —
  the release PR must merge first (often a human step). If it's next-cycle work, continue and
  say so.

## Step 3 — Fast-forward the release branch

```bash
git checkout <release-branch>
git pull --ff-only origin <release-branch>
git status --porcelain       # empty
git rev-parse --short HEAD    # the commit that will be tagged
```

If `--ff-only` fails, your local branch diverged — investigate; don't force or blind-merge a
shared release branch.

## Step 4 — Decide the version

If the user pinned a bump level or an explicit version, use it. Otherwise decide it from the
range since the last release, and confirm with the user before tagging.

```bash
LATEST=$(git tag --sort=-v:refname | head -1)
git log --oneline --no-decorate "$LATEST"..HEAD
git diff --stat "$LATEST"..HEAD
git log --format='%s%n%b' "$LATEST"..HEAD | grep -iE 'BREAKING CHANGE|!:' || echo "no breaking markers"
```

Classify what changed — ignore pure bookkeeping commits (CI-only tweaks, lockfile bumps, and
any internal process trail; the `changelog` skill's "filter for signal" section describes this
filtering in detail). What remains — features, fixes, interface changes — is what the version
communicates.

| Bump | When |
|---|---|
| **major** | An incompatible change to something already shipped: a removed or renamed CLI command / flag / API / config key, a changed on-disk or wire format, a dropped platform or capability. Flagged by `BREAKING CHANGE:` / `!:`, or evident from the diff. **Pre-1.0 exception:** while the latest tag is `0.x.y` there is no 1.0 stability promise yet — put breaking *and* feature work in the **minor** slot and call the breaking part out in the notes. |
| **minor** | New capability with no incompatible removal — a new command / subcommand / flag / endpoint, or a behavior change to something that already shipped. |
| **patch** | Bug fixes and internal-only changes; no interface additions or removals. |

Sanity-check against history: `git tag --sort=-v:refname` shows how comparable past releases
were numbered here (feature releases often took a minor bump; fix-only releases a patch). State
the decision and a one-line reason.

Prove the target is free:

```bash
VERSION=<decided>       # with the repo's prefix convention, e.g. v1.5.0 or 1.5.0
git tag -l "$VERSION"; git ls-remote --tags origin "$VERSION"      # both empty
gh release view "$VERSION" >/dev/null 2>&1 && echo "RELEASE EXISTS — stop" || echo "free"
```

## Step 5 — Tag and push

Create the tag in the repo's convention. Lightweight:

```bash
git tag "$VERSION" && git push origin "$VERSION"
```

or annotated, if that's what the repo uses:

```bash
git tag -a "$VERSION" -m "$VERSION" && git push origin "$VERSION"
```

Pushing the tag triggers the pipeline and is the point of no return — undoing means deleting a
public tag and Release. Re-check `git rev-parse --short HEAD` is the intended commit first.

## Step 6 — Watch the release pipeline

Find the tag's workflow run and watch it to completion (see `gh-cli` →
`references/actions-ci.md`):

```bash
gh run list --event push --limit 15
RUN_ID=$(gh run list --event push --limit 15 --json databaseId,headBranch,workflowName \
  --jq "[.[] | select(.headBranch==\"$VERSION\")][0].databaseId")
gh run watch "$RUN_ID" --exit-status --interval 20
```

`--exit-status` makes `gh run watch` exit non-zero if the run fails.

## Step 7 — Verify the GitHub Release

```bash
gh release view "$VERSION"
```

Confirm it exists, is **not** a draft, and carries the assets the workflow's release step is
supposed to attach (from Step 1). A green run with a missing asset still counts as a failed
release — go to Step 8. Green run + complete Release → Step 9.

## Step 8 — Failed pipeline or incomplete Release

1. Get the detail — `gh run view "$RUN_ID" --log-failed`, and `gh run view "$RUN_ID" --json url
   --jq .url`. Identify the failing job, the step, and the error line(s).
2. **Triage the cause:**
   - **Transient** (runner / network / cache / registry hiccup): re-run —
     `gh run rerun "$RUN_ID" --failed` — and go back to Step 6.
   - **Real defect** (build break, packaging bug, workflow error, missing asset): don't keep
     re-running. File an issue and stop. The tag stays; the Release is incomplete until someone
     fixes the cause and re-runs the workflow or re-pushes the tag.
3. **File the issue** via the `new-issue` skill (or `gh issue create` — `gh-cli` has the
   syntax). Include: the tag, the run URL, the failing job / step, a short log excerpt, and the
   current state (tag pushed, Release missing / incomplete). Report the issue URL and stop —
   don't run the changelog step against an incomplete Release.

## Step 9 — Release notes

The pipeline most likely published GitHub's auto-generated notes (a raw merged-PR list).
Replace them with proper notes via the `changelog` skill:

> Regenerate the GitHub release description for tag `<VERSION>` in Keep a Changelog format,
> covering all changes since `<LATEST>`.

Review its draft, confirm, let it publish, then re-check `gh release view "$VERSION"`.

## Step 10 — Restore the workspace

```bash
git checkout <original-branch>
git status --porcelain     # empty
```

End state:

- Tag `<VERSION>` on `origin` at the released commit.
- GitHub Release `<VERSION>` published, not a draft, with every expected asset — **or**, on
  failure, a filed issue and a clear report, and no changelog.
- Local release branch fast-forwarded to the tag; working tree clean; back on the pre-release
  branch.

## Quality Criteria

- The version bump is justified against the actual diff since the last tag, not guessed — and
  the pre-1.0 rule is applied when the latest tag is `0.x.y`.
- The tag matches the repo's existing prefix and object-type (lightweight / annotated)
  convention.
- The pushed tag's target commit was confirmed before the push.
- "Done" means the run is green *and* the Release has every asset the workflow should attach —
  not just that the run finished.
- A failed pipeline produces a filed issue with the run URL and failing step, not a silent
  retry loop or a half-published release left unmentioned.
- Release notes are regenerated via `changelog`, not left as CI's raw PR list.

## Common Pitfalls

- **Assuming the default branch is the release branch** — some projects tag from a `release/*`
  or integration branch; Step 1 is there to catch this.
- **Wrong tag format** — adding or dropping a `v` prefix, or pushing a lightweight tag where the
  repo uses annotated (or vice versa).
- **Calling it done at "run succeeded"** — without opening the Release to check it's published
  and complete.
- **Retry-looping a real build failure** — re-running a deterministic failure instead of
  triaging it and filing an issue.
- **Running the changelog step against an incomplete Release** — polishing notes on a release
  that isn't actually out.
- **Leaving the workspace on the release branch** in a mid-release or detached state.

## References

This skill leans on its sibling skills rather than bundling its own references:

- `gh-cli` — exact `gh` syntax; see `references/actions-ci.md` (watching runs) and
  `references/release-mgmt.md` (releases and assets).
- `changelog` — regenerating the release description in Keep a Changelog format.
- `new-issue` — filing the failure issue when the pipeline breaks.
