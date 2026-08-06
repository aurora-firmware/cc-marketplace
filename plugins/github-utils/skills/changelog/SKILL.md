---
name: changelog
description: >-
  Generate Keep a Changelog (keepachangelog.com/en/1.0.0) formatted release
  notes for specific git tags/versions and publish them as GitHub release
  descriptions via `gh`. Use whenever the user asks to write, draft,
  regenerate, fix, or update a changelog, release notes, or release
  descriptions for one or more versions or tags — e.g. "update the release
  notes for v1.2.0", "generate changelogs for the last 3 releases", "the
  GitHub release descriptions are just raw PR lists, rewrite them properly",
  "draft changelog entries for 0.4.0 through 0.5.0", or "regenerate all
  release descriptions in keepachangelog format". Trigger even when the user
  doesn't say "keepachangelog" or name the format explicitly, as long as
  they're asking about release notes, descriptions, or changelogs tied to
  specific versions or git tags.
---

# Changelog

Turn git history into Keep a Changelog–formatted release notes and publish
them to GitHub releases. The hard part isn't the formatting — it's telling
apart the commits a release's actual users care about from the commits that
only exist to keep an internal process moving. Get that filtering right and
the rest is mechanical.

## Workflow

### 1. Resolve which tags are in scope

Fetch tags and get the authoritative order:

```bash
git fetch --tags
git tag -l | sort -V
```

Resolve whatever the user said against that list:

- Explicit names ("0.4.0 and 0.4.1", "v1.2.0") → use as given, but verify
  each exists (`git rev-parse <tag>`) before doing any work.
- A range ("0.4.0 through 0.5.0", "0.4.0..0.5.0") → the inclusive slice of
  the sorted tag list between those two.
- Relative phrasing ("the last 3 releases", "everything since 0.3.0", "all
  releases") → resolve against the sorted list yourself; don't guess.
- A single version → just that one tag.

Don't assume a tag has a published GitHub release. A tag can exist with no
release attached (e.g. it was cut and then superseded before publishing) —
`scripts/publish-release-notes.sh` skips those automatically rather than
creating new releases, since creating a release is a bigger action than
editing one and shouldn't happen implicitly.

### 2. Pull the commit history per tag

```bash
${CLAUDE_PLUGIN_ROOT}/skills/changelog/scripts/list-tag-commits.sh <tag> [tag...]
${CLAUDE_PLUGIN_ROOT}/skills/changelog/scripts/list-tag-commits.sh --all
${CLAUDE_PLUGIN_ROOT}/skills/changelog/scripts/list-tag-commits.sh --last 3
```

Run it from inside the target repo (it operates on whatever git repo the
current working directory is in) — `${CLAUDE_PLUGIN_ROOT}` always points back
to this plugin's install location, so the script works against any repo
you're in, not just one project.

This prints non-merge commit subjects for each tag, scoped to that tag's
true predecessor in the *full* tag history — not just the previous tag you
happened to ask about. That distinction matters: a tag with no GitHub
release still has to count as a boundary, or its commits get silently
folded into the wrong neighboring release, or double-counted across two.

If the commit subjects alone are too terse to tell what a change was about,
cross-reference merged PR titles — `gh pr list --search "is:merged"` or the
existing (soon to be replaced) release body's "What's Changed" section often
carries a more polished, human-written summary than the commit message does.

### 3. Filter for signal, not noise

Keep a Changelog is written for people deciding whether to upgrade. A commit
belongs in the draft if it describes a product-facing change: new
capability, behavior change, bug fix, removed capability, or a security fix.
It doesn't belong if its entire purpose was internal bookkeeping — updating
a status tracker, recording a review verdict, moving a work item from one
folder to another.

Some repos run their own internal process automation on top of git — a
ticket-lifecycle bot, an AI-team workflow, a bookkeeping convention recorded
in their `CLAUDE.md`/`CONTRIBUTING.md` — and it leaves a very recognizable
trail of process commits once you've seen it. As a concrete example,
`aurora-firmware/the-intern` runs an AI-team development process (see its
root `CLAUDE.md`) that produces commits like these — drop commits matching
these patterns on sight when working in that repo, or a repo with an
equivalent convention:

- `chore(tasks): move T-NNN to ...`, `chore(tasks): record ... work log`,
  `chore(tasks): merge T-NNN ...`, `chore(tasks): escalate/resume/refresh ...`
- `chore(bugs): move B-NNN to ...`, `chore(bugs): record ... diagnosis`,
  `chore(bugs): file B-NNN ...`
- `docs(tasks): record ... review verdict`, `docs(bugs): record ... review
  verdict`
- `docs(reports): add ... progress report`
- Pure `test(...)` or `style(...)` commits, unless the test coverage change
  is itself the newsworthy part (rare)

Do **not** drop a `feat(...)` or `fix(...)` commit just because it also
references a task or bug ID — the ID is traceability, the change is real.
Keep the ID in parentheses at the end of the bullet (e.g. `(B-016)`) when it
reads naturally; drop it if it doesn't add anything for a reader without
access to this repo's issue tracker.

In any other repo, the specific patterns above won't apply verbatim, but the
underlying test does: does this commit change what a user of the software
can do, or does it only change the state of an internal tracking system?
Filter on that question, not on the literal strings above — skim a page or
two of `git log` first if you're not sure what a repo's own bookkeeping
convention looks like.

### 4. Categorize what's left

Keep a Changelog defines six sections, always in this order, and you only
include the ones that have content:

| Section | What goes here |
|---|---|
| Added | New capability that didn't exist before |
| Changed | A behavior change to something that already existed |
| Deprecated | Still works, but on its way out |
| Removed | A capability, flag, config key, or file format that's gone |
| Fixed | A bug fix |
| Security | Anything closing a vulnerability or hardening a trust boundary |

Commit-type prefixes are a starting signal, not a verdict:

- `feat(...)` is usually **Added**, but if it extends or reshapes something
  that already shipped rather than introducing it fresh, it's **Changed**.
- `fix(...)` is usually **Fixed**, but if the bug was a security boundary
  (an auth/permission gate, an allow-list, a trust check), prefer
  **Security** — it's more useful to a reader scanning for that.
- `refactor(...)` and internal `chore(...)` are normally invisible to users
  and should be dropped — include them only if they changed something
  observable (a config shape, a CLI flag, a released artifact).
- A commit that deletes a legacy format, config key, or code path is
  **Removed**, even if the commit itself is typed `fix` or `chore`.

Use judgment; these are read as prose by a human deciding whether to
upgrade, not as a mechanical transform of commit types.

### 5. Draft one file per tag

Write each release's notes as its own markdown file, named after the tag,
into a scratch directory (not into the repo). Format:

```markdown
### Added

- Sentence describing the capability, in plain language, not a copy of the commit subject

### Fixed

- What was broken, what it does now (ID)

---
**Full Changelog**: https://github.com/<owner>/<repo>/compare/<prev-tag>...<tag>
```

Omit the `Full Changelog` footer for the very first tag in the repo (there's
no predecessor to compare against). Omit any section with nothing in it —
don't pad a small release with empty headers, and don't inflate a two-line
release into a wall of bullets. A release with one real commit deserves one
bullet.

Write in plain language a reader outside the project would understand —
translate commit-speak ("wire preflight to persistence") into what changed
for them ("scheduled runs are now checked against the active policy before
executing"). If you genuinely can't tell what a terse commit means well
enough to describe it plainly, it's better to look at the diff
(`git show <hash>`) than to guess.

### 6. Show the drafts, then confirm before publishing

Editing a release description is visible to everyone watching the repo —
show the user what you're about to write and get an explicit go-ahead
before running the publish step. This isn't a formality: release notes are
often the only place a user-facing summary of a release exists, and a wrong
one is wrong in public.

### 7. Publish

```bash
${CLAUDE_PLUGIN_ROOT}/skills/changelog/scripts/publish-release-notes.sh <notes-dir> [tag...]
```

Applies each `<tag>.md` in the drafts directory via `gh release edit`. If it
fails with an HTTP 404, that almost always means the active `gh` account has
read-only access to the repo (`gh auth status` to check, `gh auth switch` to
pick a different account) — GitHub returns 404 rather than 403 for
write endpoints the caller can't see. The script prints this hint on
failure, but it's worth knowing up front so a permission problem doesn't
read as "the release doesn't exist."
