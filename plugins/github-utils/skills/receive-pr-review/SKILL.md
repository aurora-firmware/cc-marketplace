---
name: receive-pr-review
description: >-
  Guides a developer through responding to an existing PR review: reads the
  local pr-<number>-review.md report (written by the pr-review skill) and
  the PR's GitHub review comments, takes each open finding in turn, decides
  whether the reviewer is right, and either changes the code (or docs, or
  the PR's claims) or replies with a justification or clarification that
  shows the finding doesn't hold, then records the response back into the
  report so a later pr-review re-review can verify it. Use this whenever the
  user wants to act on, respond to, triage, or work through PR review
  feedback — "go through the PR review comments", "what should I do about
  this review", "address the findings in pr-19-review.md", "handle the
  reviewer's feedback" — even if they don't say "receive" or "triage".
  Requires an existing pr-<number>-review.md; if there isn't one, suggest
  running pr-review first instead of guessing at findings.
---

# receive-pr-review

The developer's half of a review ⇄ response loop with `pr-review`.

The reviewer reports where the change differs from what it claims or from
the project's rules — what is wrong and why, never how to fix it. The
developer answers **every** finding: change the code (or docs, or the PR's
claims) if the reviewer is right, or demonstrate that the finding doesn't
hold. Neither answer closes a finding; the reviewer verifies it on the next
`pr-review` pass, and the loop continues until both agree on every finding.

This skill only adds annotations under a finding; it never rewrites the
reviewer's original text.

## Step 1 — Identify the PR and the report

Resolve the PR the same way `pr-review` does: a URL, `owner/repo#N`, a bare
number against the current repo, or the current branch's PR.

Look for `pr-<number>-review.md` in the working directory (or wherever the
user points). If it isn't there, this skill has nothing to work from — say
so and suggest running the `pr-review` skill first. Don't invent findings
to answer.

## Step 2 — Gather the findings you owe a response to

From the report, collect every finding that is:

- Annotated `**Status:** Open` — including one the reviewer reopened or
  rebutted (its last note is a `**Reviewer:**` note you haven't answered), or
- Annotated `**Status:** Needs Clarification` the reviewer has since
  answered, or
- Has no annotation at all (the default state for an untouched finding).

Skip anything `Fixed (confirmed ...)` or `Acknowledged` (the reviewer has
agreed), and anything marked `Fixed`, `Won't Fix` or `Needs Clarification`
with no reviewer note after it (waiting on the reviewer).

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
as the annotation — reflect it into the report rather than re-answering
something already answered.

## Step 3 — Gather the context to judge against

Each finding has a **Basis**: a claim, a project rule, or a defect. To judge
the finding you need what it was measured against:

- The PR description, linked issue and commit messages (the claims)
- `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/`, `docs/adr/`,
  `docs/decisions/`, `*design*.md`, `*spec*.md`, an architecture section in
  the README (the rules)

If a finding cites a rule you can't find, say so in the final summary.

## Step 4 — Answer each finding

Take the findings one at a time. For each, **verify before deciding** —
reproduce what the reviewer describes, read the code at the cited location,
read the claim or rule it cites. Agreeing or disagreeing from the report's
text alone is how wrong fixes and wrong rebuttals both happen.

Then choose one:

- **The reviewer is right → change it.** Edit the code, docs, or
  configuration so the finding no longer holds. If the finding is that a
  claim in the PR is false, you may make the claim true (fix the code) or
  correct the claim (edit the PR description or docs) — whichever reflects
  what the change is actually meant to do. Fix the cause the finding
  describes, not just the one line it points at: the reviewer will re-check
  everything the finding's Basis covers. Run the relevant tests.
- **The reviewer is wrong, or it's out of scope → justify.** A bare
  "intentional" or "I prefer it" doesn't count; build the case from evidence
  and say which kind it is:
  - *Misinterpretation* — what the claim or rule actually says, or what the
    code actually does (cite the code, test output or doc that shows it).
  - *Out of scope* — the issue is real but not something this change set out
    to alter; point to the task's stated scope and show the code is
    pre-existing and untouched. Offer to open a follow-up issue so the
    concern isn't lost.
  - *Intentional and sanctioned* — a project rule, ADR or design doc
    requires the behavior; cite it.
- **The finding is unclear → ask.** Don't guess at the reviewer's intent and
  don't fix a guess. Write a specific question that shows what you checked
  and where it stopped making sense, grounded in Step 3's context (e.g. "the
  spec at `docs/adr/0004-session-store.md` says X — is this case actually
  reachable given that?").

Don't fix what the finding doesn't describe; extra changes are more for the
next review to check. A valid finding too large for this PR (a refactor, a
design change) gets the out-of-scope justification, with where it will be
tracked.

Status mapping: fix → `Fixed`; justification → `Won't Fix`; question →
`Needs Clarification`.

## Step 5 — Record the response in the report

For every item that came from the report (Step 2), write your note under it,
preserving the original finding text above untouched:

```markdown
#### [<severity>] <title> — `<file>:<line>`
**Basis:** ...
<original finding body>

> **Developer:** <what you did, or your justification, or your question>
**Status:** Open | Fixed | Won't Fix | Needs Clarification
```

- `Fixed` — say what you changed and why that resolves the finding. Commit
  first and cite the SHA (`` Fixed in `a3f9c2d` — every call site of
  `verify_token()` now uses `ConstantTimeEq` ``); re-review checks the PR's
  commit history, so an unpushed fix will be reopened.
- `Won't Fix` — lead with the evidence (code, test, doc or rule), then the
  conclusion. Anything taken on faith will come back `Open`.
- `Needs Clarification` — the specific question, nothing more.

Add your note below any existing thread rather than replacing it. When the
reviewer rebutted a `Won't Fix`, answer its specific point with new evidence
or concede and fix it; repeating the argument stalls the loop.

Items that came only from GitHub (Step 2, not already in the report) don't
get added as new findings — they're handled in Step 6 instead.

## Step 6 — Summarize, hand back to the reviewer, offer GitHub sync

Show the user a summary grouped by outcome: what was fixed (and where),
what was disputed and the evidence offered, what's waiting on a clarification
(with the questions). Call out `critical` findings regardless of outcome.

Nothing is *resolved* yet: every item now waits for the reviewer. Remind the
user to commit and push the fixes, then re-run `pr-review`. The loop is
finished only when `pr-review` reports agreement on every finding.

This is local-only by default: the report is updated, nothing is sent to
GitHub. If the user asks, in this conversation, to also sync to GitHub,
draft a reply for each item that has a corresponding GitHub review comment
(a fixed-in-commit note, the justification, or the clarifying question),
show the drafts, and only after explicit confirmation post them:

```bash
gh api repos/<owner>/<repo>/pulls/comments/<comment-id>/replies -f body="<drafted reply>"
```

Never post without showing the drafts and getting confirmation first —
same rule `pr-review` follows before publishing findings.
