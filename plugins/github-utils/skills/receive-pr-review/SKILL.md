---
name: receive-pr-review
description: >-
  Guides a developer through responding to an existing PR review: reads the
  local pr-<number>-review.md report (written by the pr-review skill) and
  the PR's GitHub review comments, decides for each open item whether it's
  valid to fix, needs clarification from the reviewer, or should be
  declined, applies straightforward fixes directly, and records the
  decision back into the report so a later pr-review re-review can pick up
  where this left off. Use this whenever the user wants to act on, respond
  to, triage, or work through PR review feedback — "go through the PR
  review comments", "what should I do about this review", "address the
  findings in pr-19-review.md", "handle the reviewer's feedback" — even if
  they don't say "receive" or "triage". Requires an existing
  pr-<number>-review.md; if there isn't one, suggest running pr-review
  first instead of guessing at findings.
---

# receive-pr-review

Work through an existing PR review as a developer would: figure out what's
actually worth fixing, what needs the reviewer to clarify something first,
and what's a reasonable disagreement — then act on that triage and leave a
trail the reviewer can follow on the next pass.

This skill only ever adds annotations under a finding; it never rewrites
the reviewer's original finding text. That history is what makes a
re-review possible.

## Step 1 — Identify the PR and the report

Resolve the PR the same way `pr-review` does: a URL, `owner/repo#N`, a bare
number against the current repo, or the current branch's PR.

Look for `pr-<number>-review.md` in the working directory (or wherever the
user points). If it isn't there, this skill has nothing to work from — say
so and suggest running the `pr-review` skill first. Don't invent findings
to triage.

## Step 2 — Gather open items

From the report, collect every finding that is:

- Annotated `**Status:** Open` or `**Status:** Needs Clarification`, or
- Has no annotation at all (the default state for an untouched finding).

Skip anything already `Fixed`, `Fixed (confirmed ...)`, `Won't Fix`, or
`Acknowledged` — it's already resolved.

Then fetch the PR's GitHub review comments and check for anything not yet
reflected in the report — a human reviewer's inline comments count too, not
just findings the `pr-review` skill wrote:

```bash
gh pr view <N> --repo <owner>/<repo> --json number,title,url,headRefOid
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate
gh api repos/<owner>/<repo>/pulls/<N>/reviews --paginate
```

Match GitHub comments against the report by file/line/body — a comment
already represented as a finding in the report is not a separate item. If a
GitHub comment thread already has a developer reply resolving it (posted
outside this skill, e.g. by a human directly on GitHub), treat that reply
as the annotation — reflect it into the report rather than re-triaging
something already answered.

## Step 3 — Gather architectural context

Look for the project's own design docs, if any exist, so triage decisions
are grounded in real constraints rather than guesses:

- `docs/`, `docs/adr/`, `docs/decisions/`
- Files matching `*design*.md` or `*spec*.md` under `docs/`
- An architecture section in `README.md` or `CONTRIBUTING.md`

If nothing turns up, say so explicitly in the final summary rather than
implying architectural context was considered when none existed.

## Step 4 — Triage each item

For every item gathered in Step 2 that isn't already answered by an
existing GitHub reply, decide one of:

- **Valid, small/unambiguous** — fix it now. Edit the code or docs directly
  in this session.
- **Valid, large/ambiguous** — describe the fix that should happen; don't
  apply it. Forcing a rushed edit to close out a finding that actually
  needs a dedicated pass (a refactor, a design change) does more harm than
  leaving it open with a clear description.
- **Needs clarification** — don't guess at the reviewer's intent. Write a
  specific question. If Step 3 found relevant architecture context, ground
  the question in it (e.g. "the spec at `docs/adr/0004-session-store.md`
  says X — is this case actually reachable given that?").
- **Disagree / won't fix** — requires a rationale tied to the actual code or
  an architecture doc, not a bare preference. "This is intentional because
  X" needs an X that holds up.

## Step 5 — Update the report

For every item that came from the report (Step 2), write the annotation
block under it, preserving the original finding text above untouched:

```markdown
#### [<severity>] <title> — `<file>:<line>`
<original finding body>

> **Developer:** <your note — what you did, or your question, or your rationale>
**Status:** Open | Fixed | Won't Fix | Needs Clarification
```

For a finding that already had an annotation from a previous round (e.g.
`Needs Clarification` that the reviewer already answered in a re-review),
add your new note below the existing one rather than replacing it.

Items that came only from GitHub (Step 2, not already in the report) don't
get added as new findings — they're handled in Step 6 instead.

## Step 6 — Summarize, offer GitHub sync

Show the user a summary grouped by outcome: what was fixed (and where),
what's pending clarification (with the drafted questions), what was
declined and why. Call out `critical`-severity findings explicitly
regardless of outcome.

This is local-only by default: the report is updated, nothing is sent to
GitHub. If the user asks, in this conversation, to also sync to GitHub,
draft a reply for each item that has a corresponding GitHub review comment
(a fixed-in-commit note, or the clarifying question), show the drafts, and
only after explicit confirmation post them:

```bash
gh api repos/<owner>/<repo>/pulls/comments/<comment-id>/replies -f body="<drafted reply>"
```

Never post without showing the drafts and getting confirmation first —
same rule `pr-review` follows before publishing findings.
