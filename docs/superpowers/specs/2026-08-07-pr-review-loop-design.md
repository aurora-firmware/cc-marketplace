# PR Review Loop: Re-review + receive-pr-review Design

## Goal

Close the loop on `github-utils`'s PR review workflow. Today `pr-review`
always runs a full review from scratch, and there is no structured way for a
developer to work through the findings and let the reviewer pick up where it
left off. This adds:

1. **Re-review mode** to the existing `pr-review` skill — when a
   `pr-<N>-review.md` report already exists, review only what changed since
   the last round instead of starting over.
2. **A new `receive-pr-review` skill** — guides a developer through triaging
   a review report (and any GitHub PR comments) into fixes, clarification
   requests, or declines, and records those decisions back into the report.

## The loop

```
pr-review (full)        → writes pr-<N>-review.md, records reviewed commit
receive-pr-review       → triages open findings, fixes/asks/declines,
                           annotates the report, optionally syncs to GitHub
  (developer pushes new commits)
pr-review (re-review)   → detects existing report, diffs only new commits,
                           confirms fixes, answers clarification requests,
                           reviews new code, updates the report in place
  (repeat until no open findings)
```

Both skills read and write the same `pr-<N>-review.md` file, which is the
shared state between "what the reviewer found" and "what the developer did
about it."

## Part 1 — `pr-review`: re-review mode

### Step 0 — Determine review mode (new, runs before today's Step 1)

After resolving the PR reference (same resolution logic as today: URL,
`owner/repo#N`, bare number, or current branch's PR), check the working
directory for `pr-<number>-review.md`.

- **Not found** → proceed with the existing Steps 1–8 exactly as they are
  today (full review). No behavior change for first-time reviews.
- **Found** → switch to **re-review mode** and follow
  `references/re-review.md` for the rest of the flow instead of Steps 1–8.

### Re-review flow (`references/re-review.md`)

1. **Read the existing report.** Pull the `**Reviewed through commit:**`
   line and, for every existing finding, its current `Status` and any
   `> **Developer:**` note.
2. **Fetch current PR state**, same calls as today's Step 1, plus any new
   GitHub review comments/threads posted since the last round.
3. **Compute the new diff**: the range from the recorded commit to the
   current head. Use local `git diff <old>..<new>` if the PR's repo is
   checked out in the working directory (fetching the head first if
   needed); otherwise `gh api repos/<owner>/<repo>/compare/<old>...<new>`.
4. **Reconcile findings marked `Fixed`** — spot-check each against the new
   diff and current file content at that location.
   - Looks addressed → `Status: Fixed (confirmed <date>)`.
   - Doesn't → reopen with a short reason (`Status: Open` plus a one-line
     note on what's still wrong), don't silently accept the claim.
5. **Reconcile findings marked `Needs Clarification`** — answer the
   developer's question directly, appended under their note in the report.
   If the answer resolves the finding, close it; if it doesn't, leave it
   `Open` with the answer now available as context.
6. **Reconcile findings marked `Won't Fix`** — accept the rationale and set
   `Status: Acknowledged`, *except* `critical`-severity findings, which get
   flagged back for explicit human attention instead of being silently
   closed on a developer's say-so.
7. **Review the new diff** using the same classify → filter → tier → scope
   agents machinery as today's Steps 2–6, scoped only to what changed since
   the last recorded commit. This catches issues introduced by the fix
   itself or by unrelated new commits.
8. **Update the report in place**: refresh statuses on existing findings,
   append newly found issues under the correct scope section, overwrite
   `Reviewed through commit` with the new head SHA, and append one line to
   the **Re-review log** (date, commit, one-line summary of the round).
9. **Publish gate**, same confirmation requirement as today's Step 8: offer
   to post *only the new* findings as inline comments. For findings just
   confirmed fixed that originated from a published GitHub comment, offer to
   reply on that thread (e.g. "confirmed fixed in `<sha>`") and resolve it.
   Nothing is posted without explicit confirmation in the session.

### Report format extension (Step 7 template)

Each finding gains an optional annotation block, written by
`receive-pr-review` (or by re-review itself for clarification answers) and
read by re-review on the next round:

```markdown
#### [warning] Token compared with non-constant-time equality — `src/server/auth.rs:142`
<original finding body — never edited after the fact>

> **Developer:** Fixed in `a3f9c2d` — switched to `subtle::ConstantTimeEq`.
**Status:** Fixed
```

`receive-pr-review` sets `Status` to one of `Open` (default, no annotation
shown), `Fixed`, `Won't Fix`, or `Needs Clarification`. Re-review then
refines a status it reconciles, rather than inventing new values:
`Fixed` → `Fixed (confirmed <date>)` once verified, or back to `Open` (with
a reason) if the fix didn't land; `Won't Fix` → `Acknowledged` once
accepted, or left as `Won't Fix` with a flag for human attention if the
finding was `critical`-severity. The reviewer's original finding text is
never rewritten — reconciliation adds to the annotation, it doesn't erase
history.

Two additions elsewhere in the report:

- In **Review notes**: `**Reviewed through commit:** <sha>` — the anchor
  re-review uses to compute the next diff. Present after the first full
  review; overwritten each re-review round.
- A new **Re-review log** section (after Review notes), append-only:
  ```markdown
  ## Re-review log
  - 2026-08-07 @ `a9f1e3c`: 1 finding confirmed fixed, 1 new finding added
  ```

## Part 2 — `receive-pr-review` skill (new)

Location: `plugins/github-utils/skills/receive-pr-review/`. Same plugin as
`pr-review`, `gh-cli`, `new-issue`, `changelog`.

### Step 1 — Identify the PR and the report

Resolve the PR the same way `pr-review` does (URL, `owner/repo#N`, bare
number, or current branch's PR). Look for `pr-<N>-review.md` in the working
directory. If it isn't there, this skill has nothing to triage — say so and
suggest running `pr-review` first, rather than inventing findings to act on.

### Step 2 — Gather open items

Collect everything not yet resolved:

- Findings in the report with `Status: Open` or `Needs Clarification` (or no
  status yet, i.e. untouched since the review was written).
- GitHub PR review comments/threads (`gh api .../pulls/<N>/comments`,
  `.../pulls/<N>/reviews`) not already reflected in the report — this
  includes a human reviewer's inline comments, not just `pr-review`'s own.

Findings already `Fixed`/`Won't Fix`/`Acknowledged` are skipped.

### Step 3 — Gather architectural context

Generic discovery in the target repo, no fixed path assumed: `docs/`, ADR
folders (`docs/adr/`, `docs/decisions/`), design/spec docs (matching
`*design*.md`, `*spec*.md` under `docs/`), and architecture sections in
README/CONTRIBUTING. If nothing is found, proceed on code understanding
alone and say so explicitly in the summary — don't imply architectural
context was considered when none existed.

### Step 4 — Triage each item

For every open finding/comment, decide:

- **Valid, small/unambiguous** → fix it now — edit the code or docs
  directly in this session.
- **Valid, large/ambiguous** → describe the fix that should happen; don't
  apply it. A finding that needs a dedicated refactor shouldn't get a rushed
  edit just to close it out.
- **Needs clarification** → don't guess at intent. Draft a specific
  question, grounded in the architecture context from Step 3 when relevant
  (e.g. "the spec in `docs/adr/0004-session-store.md` says X — is this case
  actually reachable given that?").
- **Disagree / won't fix** → requires a rationale tied to the actual code or
  architecture, not a bare preference ("this is intentional because the
  spec at `docs/...` says X").

### Step 5 — Update the report

For every triaged item that came from the report, write the annotation
block from Part 1 under it: `> **Developer:** <note>` and the resulting
`Status`. Never edit the reviewer's original finding text.

### Step 6 — Summarize, offer GitHub sync

Show the user: what was fixed (and where), what's pending clarification
(with the drafted questions), what was declined and why. This stays local
by default — no GitHub calls. If the user asks, in this conversation, to
also sync to GitHub, draft replies to the corresponding inline comment
threads (fixed-in-commit note, or the clarifying question) and post them
with `gh api` only after showing the drafts and getting explicit
confirmation — the same gate pattern as `pr-review`'s Step 8.

## Files touched

- `plugins/github-utils/skills/pr-review/SKILL.md` — add Step 0, extend
  Step 7's template, extend Step 8, add the new reference to the file list.
- `plugins/github-utils/skills/pr-review/references/re-review.md` — new.
- `plugins/github-utils/skills/pr-review/evals/evals.json` — append one
  eval exercising re-review mode; existing 4 untouched.
- `plugins/github-utils/skills/receive-pr-review/SKILL.md` — new skill.
- `plugins/github-utils/skills/receive-pr-review/evals/evals.json` — new,
  following the existing `{prompt, expected_output, files}` format.
- `plugins/github-utils/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` — bump `1.2.0` → `1.3.0`, update
  description/keywords (matches this repo's pattern of a version bump per
  skill addition, seen in the `new-issue` and `changelog` commits).

## Testing

This repo's existing convention is eval-based (`evals/evals.json` with
`prompt`/`expected_output` pairs per skill), not unit tests. Follow that
convention rather than introducing a new testing approach — add evals for
the new re-review path and for `receive-pr-review`.

## Out of scope

- Automated conflict resolution when the developer's fix and a re-review
  finding disagree beyond what's described in Part 1 step 4 — anything more
  than "reopen with a reason" is a human problem, not this skill's.
- Multi-reviewer consolidation (e.g. merging annotations from two different
  people running `receive-pr-review` concurrently) — single-developer,
  single-report workflow only, matching how `pr-review` is used today.
