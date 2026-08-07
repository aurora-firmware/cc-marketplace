# PR Review Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add re-review mode to the `pr-review` skill and a new `receive-pr-review` skill, so a reviewer and a developer can iterate on a PR through a shared `pr-<N>-review.md` report instead of starting from scratch every round.

**Architecture:** Two markdown-driven Claude Code skills in the existing `github-utils` plugin. `pr-review` gains a mode-detection step (Step 0) that branches to a new `references/re-review.md` flow when a report already exists. The new `receive-pr-review` skill reads that same report plus live GitHub PR comments, triages open items, and annotates the report. No application code — these are all skill prompt files (`SKILL.md`, `references/*.md`), JSON eval fixtures, and plugin manifests.

**Tech Stack:** Markdown (skill instructions), JSON (plugin manifests, eval fixtures), `gh` CLI (GitHub API access), `git` (diffing).

## Global Constraints

- Do not modify the 4 existing evals in `plugins/github-utils/skills/pr-review/evals/evals.json` — only append.
- Never design a flow (or an eval) that posts to GitHub without explicit in-session user confirmation — this repo's `pr-review` skill already established that rule for its own publish step, and everything new here inherits it.
- Follow this repo's existing skill conventions exactly: `SKILL.md` front-matter with `name`/`description`, a `references/` subfolder for material read conditionally, an `evals/evals.json` with `{id, name, prompt, expected_output, files}` per entry (this is `pr-review`'s own convention — match it, not `changelog`'s different `expectations`-array convention).
- Version bump: both `plugins/github-utils/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` go from `1.2.0` to `1.3.0` (this repo bumps the minor version on every skill addition — see the `new-issue` and `changelog` commits).
- This repo has no test runner or CI — `evals/evals.json` files are fixtures for an external eval harness, not something this plan executes for pass/fail. Verification steps below are structural (JSON validity, required sections present) rather than behavioral; validating actual skill behavior happens later by running the skill for real, which is out of scope for this plan.
- Eval fixtures that reference real PRs (`aurora-firmware/the-intern#19`, `cli/cli#13619`) use real file paths, line numbers, and commit SHAs pulled directly from those PRs via `gh api` — this keeps the fixtures grounded instead of inventing plausible-looking but fake code locations.
- **Assumption to flag, not silently trust:** every existing eval in this repo (`pr-review`'s 4, `changelog`'s 3) uses `"files": []` — none exercise a non-empty `files` array. Tasks 3 and 5 below use `"files": [{"path": ..., "content": ...}]` to seed a local `pr-<N>-review.md` before the eval's prompt runs, since `receive-pr-review` and re-review mode are the first skills that inherently need a pre-existing local file as input. This is the most natural reading of an otherwise-unused field, but it's unverified against whatever actually consumes `evals.json`. If the real harness expects a different shape, only the `files` arrays in the two new eval entries need adjusting — the rest of each eval (`prompt`/`expected_output`) stands regardless.

---

### Task 1: `references/re-review.md` for `pr-review`

**Files:**
- Create: `plugins/github-utils/skills/pr-review/references/re-review.md`

**Interfaces:**
- Consumes: nothing (self-contained reference file).
- Produces: a file at `plugins/github-utils/skills/pr-review/references/re-review.md` with 9 numbered `##` sections (`1.` through `9.`), consumed by Task 2's Step 0 (which points to this file) and by the report-format vocabulary (`Status: Open | Fixed | Won't Fix | Needs Clarification`, `**Reviewed through commit:**`, `## Re-review log`) that Task 2 also writes into `SKILL.md`'s Step 7 template.

- [ ] **Step 1: Write the reference file**

Create `plugins/github-utils/skills/pr-review/references/re-review.md` with exactly this content:

```markdown
# Re-review mode

Followed when Step 0 finds an existing `pr-<number>-review.md` in the
working directory. Re-review only what changed since the last round instead
of repeating the full review — the report already has agreed-on findings
and the developer's response to them.

## 1. Read the existing report

Parse `pr-<number>-review.md`:

- The `**Reviewed through commit:**` line in **Review notes** — the base
  commit for the new diff.
- Every finding's current annotation, if any:
  ```markdown
  > **Developer:** <note>
  **Status:** Open | Fixed | Won't Fix | Needs Clarification
  ```
  A finding with no annotation is treated as `Open`.

## 2. Fetch current PR state

Same calls as Step 1 of the full review:

```bash
gh pr view <N> --repo <owner>/<repo> --json number,title,body,author,state,url,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles
gh api repos/<owner>/<repo>/pulls/<N>/files --paginate
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate
gh api repos/<owner>/<repo>/pulls/<N>/reviews --paginate
```

Only comments/reviews newer than the last round matter for reconciliation —
compare timestamps against the most recent entry in the report's
**Re-review log**.

## 3. Compute the new diff

Diff from the report's recorded commit to the PR's current `headRefOid`:

- If the PR's repo is checked out in the working directory:
  ```bash
  git fetch origin pull/<N>/head
  git diff <reviewed-through-sha>..<headRefOid>
  ```
- Otherwise:
  ```bash
  gh api repos/<owner>/<repo>/compare/<reviewed-through-sha>...<headRefOid>
  ```

If the two SHAs are identical, there's nothing new to review — skip to
Step 4 (reconciliation) and tell the user no new commits were found.

## 4. Reconcile findings marked `Fixed`

For each finding annotated `Status: Fixed`, read the current file at the
finding's location (from the new diff if it's in range, otherwise the
current file content directly).

- The described fix is actually there → update to
  `**Status:** Fixed (confirmed <today's date>)`.
- It isn't, or looks incomplete/wrong → revert to `**Status:** Open` and add
  a one-line reason why it's reopened, e.g.:
  ```markdown
  > **Developer:** Fixed in `a3f9c2d` — switched to `subtle::ConstantTimeEq`.
  > **Reviewer:** Reopened — `a3f9c2d` isn't in this PR's commit range.
  **Status:** Open
  ```

Don't accept a `Fixed` claim on the developer's word alone — that's what
this step is for.

## 5. Reconcile findings marked `Needs Clarification`

For each finding annotated `Status: Needs Clarification`, read the
developer's question and answer it directly, appended under their note:

```markdown
> **Developer:** Is this null case actually reachable given the queue only
> ever enqueues validated jobs?
> **Reviewer:** Yes — `retry_job()` re-enqueues without re-validating, so
> this path is reachable from the retry flow.
**Status:** Open
```

If the answer resolves the finding outright (e.g. the developer's premise
was correct and no code change is needed), close it instead:
`**Status:** Acknowledged`.

## 6. Reconcile findings marked `Won't Fix`

Accept the developer's rationale and set `**Status:** Acknowledged` — the
finding stays in the report as a record, not reopened.

Exception: `critical`-severity findings are never silently closed on a
developer's say-so. Leave the status as `Won't Fix`, add a note flagging it
for explicit human attention, and call this out prominently in the summary
you give the user at the end of the run.

## 7. Review the new diff

Run the normal classify → filter → tier → scope-agent flow (Steps 2–6 of
the main skill) — but only against the files/lines in the Step 3 diff, not
the whole PR. A file untouched since the last round doesn't get re-reviewed
just because it was part of the original PR.

## 8. Update the report in place

- Refresh each reconciled finding's `Status` line (Steps 4–6 above).
- Append newly found issues (Step 7) under their scope's existing section,
  in the same finding format as a full review.
- Overwrite `**Reviewed through commit:**` with the new `headRefOid`.
- Append one line to **Re-review log**:
  ```markdown
  ## Re-review log
  - <date> @ `<headRefOid short>`: <N> finding(s) confirmed fixed, <N>
    reopened, <N> new finding(s) added
  ```

## 9. Publish gate

Same rule as the full review's Step 8: never post to GitHub without
explicit confirmation in the current session.

If confirmed:

- Post *only the newly found* findings (Step 7) as inline comments, same
  payload format as `references/publishing.md`.
- For findings just confirmed fixed (Step 4) that originated from a
  published GitHub review comment, reply on that comment's thread and mark
  it resolved:
  ```bash
  # Look up the review thread ID for the comment being replied to
  gh api graphql -f query='
    query { repository(owner: "<owner>", name: "<repo>") { pullRequest(number: <N>) { reviewThreads(first: 100) { nodes { id isResolved comments(first: 1) { nodes { databaseId } } } } } } }'
  # Match the thread whose comment databaseId equals <comment-id>, then:
  gh api repos/<owner>/<repo>/pulls/comments/<comment-id>/replies -f body="Confirmed fixed in <sha>."
  gh api graphql -f query='mutation { resolveReviewThread(input: { threadId: "<thread-node-id>" }) { thread { isResolved } } }'
  ```
```

- [ ] **Step 2: Verify the file's structure**

Run:
```bash
test -f plugins/github-utils/skills/pr-review/references/re-review.md && echo EXISTS
grep -c '^## ' plugins/github-utils/skills/pr-review/references/re-review.md
```
Expected: `EXISTS` then `9`.

- [ ] **Step 3: Commit**

```bash
git add plugins/github-utils/skills/pr-review/references/re-review.md
git commit -m "feat: add re-review flow reference for pr-review skill"
```

---

### Task 2: Wire re-review mode into `pr-review/SKILL.md`

**Files:**
- Modify: `plugins/github-utils/skills/pr-review/SKILL.md`

**Interfaces:**
- Consumes: `plugins/github-utils/skills/pr-review/references/re-review.md` from Task 1 (referenced by path and by its `Status`/`Reviewed through commit`/`Re-review log` vocabulary).
- Produces: an updated `SKILL.md` whose report template (Step 7) writes `**Reviewed through commit:**` and `## Re-review log` into every new `pr-<N>-review.md` — Task 3's eval fixture and Task 4's `receive-pr-review` skill both depend on that exact vocabulary being present in reports this skill produces.

This task makes 5 edits to the existing file. Apply them in order.

- [ ] **Step 1: Extend the front-matter description**

Find this exact block at the top of `plugins/github-utils/skills/pr-review/SKILL.md`:

```
description: >-
  Full multi-agent review of an open GitHub pull request using the gh CLI:
  fetches the PR and its diffs, classifies changed files by scope (source
  code, documentation, CI, security), measures each scope's complexity,
  spawns scoped reviewer agents, deduplicates their findings, writes a local
  markdown report, and offers to publish the findings as inline comments on
  the PR. Use this whenever the user asks to review, assess, or critique a
  GitHub pull request — a PR URL, a PR number, "review PR 19", "what do you
  think of this pull request", "look at this PR before I merge" — even if
  they don't say the word "review". Do not use it for reviewing local
  uncommitted changes or a local branch diff that has no PR.
---
```

Replace it with:

```
description: >-
  Full multi-agent review of an open GitHub pull request using the gh CLI:
  fetches the PR and its diffs, classifies changed files by scope (source
  code, documentation, CI, security), measures each scope's complexity,
  spawns scoped reviewer agents, deduplicates their findings, writes a local
  markdown report, and offers to publish the findings as inline comments on
  the PR. If a pr-<number>-review.md report already exists for the PR, it
  re-reviews only the new commits and the developer's responses instead of
  repeating the full review — use this for "check if PR 19 addressed my
  feedback" or simply re-running the skill on a PR already reviewed. Use
  this whenever the user asks to review, assess, or critique a GitHub pull
  request — a PR URL, a PR number, "review PR 19", "what do you think of
  this pull request", "look at this PR before I merge" — even if they don't
  say the word "review". Do not use it for reviewing local uncommitted
  changes or a local branch diff that has no PR.
---
```

- [ ] **Step 2: Extend the intro paragraph**

Find:
```
# pr-review

Review an open GitHub pull request end to end: fetch, classify, size, review
with scoped agents, consolidate, report, and optionally publish.
```

Replace with:
```
# pr-review

Review an open GitHub pull request end to end: fetch, classify, size, review
with scoped agents, consolidate, report, and optionally publish. If a report
already exists for this PR, re-review it instead — see Step 0.
```

- [ ] **Step 3: Insert Step 0 before Step 1**

Find:
```
Severity scale used throughout:

- `critical` — exploitable vulnerability, data loss, or will break things for users
- `warning` — likely bug, measurable regression, or misleading documentation
- `suggestion` — a real improvement worth considering, not a style preference

## Step 1 — Fetch the PR
```

Replace with:
```
Severity scale used throughout:

- `critical` — exploitable vulnerability, data loss, or will break things for users
- `warning` — likely bug, measurable regression, or misleading documentation
- `suggestion` — a real improvement worth considering, not a style preference

## Step 0 — Determine review mode

Resolve the PR reference the same way Step 1 does below (URL,
`owner/repo#N`, bare number against the current repo, or the current
branch's PR) — you need the PR number before you can check for a prior
report.

Check the working directory (or wherever the user asked for the report) for
`pr-<number>-review.md`:

- **Not found** — this is the first review. Continue with Step 1 below.
- **Found** — a review already exists for this PR. Do not restart the full
  review process. Instead, read `references/re-review.md` and follow it in
  place of Steps 1–8: it reviews only what changed since the last round and
  the developer's response to the prior findings.

## Step 1 — Fetch the PR
```

- [ ] **Step 4: Extend the Step 7 report template**

Find this exact block (from the Step 7 heading through the Step 8 heading):

```
## Step 7 — Write the local report

Write `pr-<number>-review.md` in the current working directory (or where the
user asked). Use this structure:

```markdown
# PR Review: <owner>/<repo>#<number> — <title>

## Summary
<2–4 sentences: what the PR does, overall assessment, count of findings by severity>

| Scope | Files | Lines changed | Tier | Findings |
|---|---|---|---|---|

## Findings
### <Scope>
#### [<severity>] <title> — `<file>:<line>`
<body>

## Skipped files
<noise-filtered files and why>

## Review notes
<what was and wasn't examined: tiers applied, context read or not, truncated patches, etc.>
```

The "Review notes" section keeps the report honest — a lite-tier diff-only
review and a full-tier contextual review carry different weight, and the
reader should know which they got.

## Step 8 — Offer to publish
```

Replace with:

```
## Step 7 — Write the local report

Write `pr-<number>-review.md` in the current working directory (or where the
user asked). Use this structure:

```markdown
# PR Review: <owner>/<repo>#<number> — <title>

## Summary
<2–4 sentences: what the PR does, overall assessment, count of findings by severity>

| Scope | Files | Lines changed | Tier | Findings |
|---|---|---|---|---|

## Findings
### <Scope>
#### [<severity>] <title> — `<file>:<line>`
<body>

## Skipped files
<noise-filtered files and why>

## Review notes
<what was and wasn't examined: tiers applied, context read or not, truncated patches, etc.>

**Reviewed through commit:** `<headRefOid>`

## Re-review log
<no re-reviews yet>
```

The "Review notes" section keeps the report honest — a lite-tier diff-only
review and a full-tier contextual review carry different weight, and the
reader should know which they got.

`**Reviewed through commit:**` and the **Re-review log** section exist for
the loop this report is part of: if this skill runs again later against the
same PR, Step 0 finds this file and switches to re-review mode
(`references/re-review.md`), which uses these fields to diff only what
changed since this run and to record each subsequent round. Leave the log
as `<no re-reviews yet>` on a first-time review — re-review appends to it,
this step never does.

A finding may later grow an annotation block once a developer has responded
to it via the `receive-pr-review` skill, or once a re-review round has
reconciled it:

```markdown
#### [<severity>] <title> — `<file>:<line>`
<body>

> **Developer:** <note>
**Status:** Open | Fixed | Won't Fix | Needs Clarification
```

Don't add this block yourself on a first-time review — a finding with no
annotation is implicitly `Open`.

## Step 8 — Offer to publish
```

- [ ] **Step 5: Add the new reference to the References list**

Find:
```
## References

- `references/source-code.md` — source scope: flag/don't-flag boundaries
- `references/documentation.md` — docs scope: flag/don't-flag boundaries
- `references/ci.md` — CI scope: flag/don't-flag boundaries
- `references/security.md` — security scope: flag/don't-flag boundaries
- `references/publishing.md` — exact gh api calls for publishing inline comments (read only at Step 8)
```

Replace with:
```
## References

- `references/source-code.md` — source scope: flag/don't-flag boundaries
- `references/documentation.md` — docs scope: flag/don't-flag boundaries
- `references/ci.md` — CI scope: flag/don't-flag boundaries
- `references/security.md` — security scope: flag/don't-flag boundaries
- `references/publishing.md` — exact gh api calls for publishing inline comments (read only at Step 8)
- `references/re-review.md` — full re-review flow, read only when Step 0 finds an existing report
```

- [ ] **Step 6: Verify the edits**

Run:
```bash
python3 - <<'EOF'
import yaml
text = open("plugins/github-utils/skills/pr-review/SKILL.md").read()
front = text.split("---")[1]
d = yaml.safe_load(front)
assert d["name"] == "pr-review"
print("frontmatter OK")
EOF
grep -c '^## Step ' plugins/github-utils/skills/pr-review/SKILL.md
grep -q 'references/re-review.md' plugins/github-utils/skills/pr-review/SKILL.md && echo REF_FOUND
grep -q '\*\*Reviewed through commit:\*\*' plugins/github-utils/skills/pr-review/SKILL.md && echo COMMIT_FIELD_FOUND
grep -q '## Re-review log' plugins/github-utils/skills/pr-review/SKILL.md && echo LOG_FOUND
```
Expected: `frontmatter OK`, then `9` (Step 0 through Step 8), then `REF_FOUND`, `COMMIT_FIELD_FOUND`, `LOG_FOUND`.

- [ ] **Step 7: Commit**

```bash
git add plugins/github-utils/skills/pr-review/SKILL.md
git commit -m "feat: add re-review mode detection and report format to pr-review"
```

---

### Task 3: Add a re-review eval to `pr-review`

**Files:**
- Modify: `plugins/github-utils/skills/pr-review/evals/evals.json`

**Interfaces:**
- Consumes: the report format from Task 2 (`**Reviewed through commit:**`, `**Status:**` annotation block).
- Produces: a 5th eval entry (`id: 4`); the existing 4 entries (`id: 0`–`3`) are untouched.

- [ ] **Step 1: Append the new eval**

Find this exact tail of the file:

```
      "expected_output": "A report where the workflow changes are classified as CI scope and security-flagged (secrets/token handling), security scope tiered at least lite, both CI and security lenses applied, overlapping findings deduplicated. No comments posted to GitHub.",
      "files": []
    }
  ]
}
```

Replace with:

```
      "expected_output": "A report where the workflow changes are classified as CI scope and security-flagged (secrets/token handling), security scope tiered at least lite, both CI and security lenses applied, overlapping findings deduplicated. No comments posted to GitHub.",
      "files": []
    },
    {
      "id": 4,
      "name": "re-review-confirms-fix-and-finds-new-diff",
      "prompt": "Please re-review https://github.com/aurora-firmware/the-intern/pull/19 — I already have a pr-19-review.md from an earlier round and pushed new commits since then. Update the same file, don't post anything to GitHub.",
      "expected_output": "Step 0 detects the existing pr-19-review.md and switches to re-review mode instead of starting a full review. It reads 'Reviewed through commit: 54955c026', diffs it against the PR's current head (23ffe0eb7), confirms the finding annotated Fixed (citing commit 037369533, the interleaved-notifications fix in admin_rpc.rs's close()) since that commit is indeed in the new commit range, reviews only the new commits (e5f8e6fd9, 037369533, 23ffe0eb7) for fresh issues rather than re-reviewing the whole PR, updates the report in place (refreshed statuses, Reviewed through commit bumped to 23ffe0eb7, a new Re-review log line), and leaves the still-open params.session finding untouched since nothing in the new diff addresses it. No comments posted to GitHub.",
      "files": [
        {
          "path": "pr-19-review.md",
          "content": "# PR Review: aurora-firmware/the-intern#19 — bob chat + admin_rpc improvements\n\n## Summary\n2 findings from the prior round.\n\n| Scope | Files | Lines changed | Tier | Findings |\n|---|---|---|---|---|\n| source | 2 | 470 | full | 2 |\n\n## Findings\n### Source\n#### [warning] `close()` races interleaved notification frames — `the-intern/service/crates/bob/src/client/admin_rpc.rs:149`\nThe close handshake reads one frame and assumes it's the close response; a notification arriving first would be misread as the response.\n\n> **Developer:** Fixed in `037369533` — close() now loops with is_notification and discards notification frames until the close response arrives.\n**Status:** Fixed\n\n#### [suggestion] `params.session` sent by the client is silently ignored by the server — `the-intern/service/crates/bob/src/cli/commands/chat.rs:209`\n`build_chat_send_params` sets `params.session` but nothing on the server side reads it.\n**Status:** Open\n\n## Skipped files\nNone.\n\n## Review notes\nFull-tier review, source surrounding code read for both files.\n\n**Reviewed through commit:** `54955c026`\n\n## Re-review log\n<no re-reviews yet>\n"
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify JSON validity and eval count**

Run:
```bash
python3 -c "
import json
d = json.load(open('plugins/github-utils/skills/pr-review/evals/evals.json'))
assert len(d['evals']) == 5
assert d['evals'][4]['id'] == 4
assert d['evals'][0]['id'] == 0  # existing evals untouched
print('OK', len(d['evals']))
"
```
Expected: `OK 5`.

- [ ] **Step 3: Commit**

```bash
git add plugins/github-utils/skills/pr-review/evals/evals.json
git commit -m "test: add re-review eval for pr-review"
```

---

### Task 4: `receive-pr-review` skill

**Files:**
- Create: `plugins/github-utils/skills/receive-pr-review/SKILL.md`

**Interfaces:**
- Consumes: the report format from Task 2 (`**Status:**` values `Open`/`Fixed`/`Won't Fix`/`Needs Clarification`, the `> **Developer:**` annotation block).
- Produces: a skill directory `plugins/github-utils/skills/receive-pr-review/` — Task 5's evals target this skill, Task 6's manifests/README list it by name `receive-pr-review`.

- [ ] **Step 1: Write the skill file**

Create `plugins/github-utils/skills/receive-pr-review/SKILL.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify the file's structure**

Run:
```bash
python3 - <<'EOF'
import yaml
text = open("plugins/github-utils/skills/receive-pr-review/SKILL.md").read()
front = text.split("---")[1]
d = yaml.safe_load(front)
assert d["name"] == "receive-pr-review"
print("frontmatter OK:", d["name"])
EOF
grep -c '^## Step ' plugins/github-utils/skills/receive-pr-review/SKILL.md
```
Expected: `frontmatter OK: receive-pr-review`, then `6` (Step 1 through Step 6).

- [ ] **Step 3: Commit**

```bash
git add plugins/github-utils/skills/receive-pr-review/SKILL.md
git commit -m "feat: add receive-pr-review skill"
```

---

### Task 5: `receive-pr-review` evals

**Files:**
- Create: `plugins/github-utils/skills/receive-pr-review/evals/evals.json`

**Interfaces:**
- Consumes: the `receive-pr-review` skill from Task 4; the report annotation format from Task 2.
- Produces: `plugins/github-utils/skills/receive-pr-review/evals/evals.json`, the last file this plan creates before the manifest/README task.

- [ ] **Step 1: Write the evals file**

Create `plugins/github-utils/skills/receive-pr-review/evals/evals.json` with exactly this content:

```json
{
  "skill_name": "receive-pr-review",
  "evals": [
    {
      "id": 0,
      "name": "reconcile-resolved-github-threads",
      "prompt": "I got review feedback on https://github.com/aurora-firmware/the-intern/pull/19 a while back and already responded to most of it on GitHub. Can you go through pr-19-review.md and update it with what's actually resolved? Don't post anything new to GitHub.",
      "expected_output": "receive-pr-review fetches the PR's GitHub review comments and finds each of the 4 seeded findings already has a developer reply on GitHub, then updates the report: the close()-races-interleaved-notifications finding (admin_rpc.rs:149) to Fixed, citing commit 0373695/23ffe0e; the params.session-ignored finding (chat.rs:209) and the tokio::select!-drops-recv-future finding (chat.rs:182) to Acknowledged, citing that they're intentionally deferred and tracked in CR-001; and the method-plus-non-null-id edge case (admin_rpc.rs:251) to Acknowledged as unreachable today per the existing GitHub reply. No findings are fabricated or re-triaged from scratch since the developer's real reasoning is already on GitHub — the annotations paraphrase it rather than inventing new rationale. No GitHub replies posted (not requested, and nothing new to say).",
      "files": [
        {
          "path": "pr-19-review.md",
          "content": "# PR Review: aurora-firmware/the-intern#19 — bob chat + admin_rpc improvements\n\n## Summary\n4 findings.\n\n| Scope | Files | Lines changed | Tier | Findings |\n|---|---|---|---|---|\n| source | 2 | 470 | full | 4 |\n\n## Findings\n### Source\n#### [warning] `close()` races interleaved notification frames — `the-intern/service/crates/bob/src/client/admin_rpc.rs:149`\nThe close handshake reads one frame and assumes it's the close response; a notification arriving first would be misread as the response.\n**Status:** Open\n\n#### [suggestion] `params.session` sent by the client is silently ignored by the server — `the-intern/service/crates/bob/src/cli/commands/chat.rs:209`\n`build_chat_send_params` sets `params.session` but nothing on the server side reads it.\n**Status:** Open\n\n#### [suggestion] `tokio::select!` drops the in-flight `recv()` future — `the-intern/service/crates/bob/src/cli/commands/chat.rs:182`\nA latent hazard, pre-existing: `tokio::select!` drops the `subscription.recv()` future whenever the other branch fires first.\n**Status:** Open\n\n#### [suggestion] Frame with both `method` and a non-null `id` is misclassified — `the-intern/service/crates/bob/src/client/admin_rpc.rs:251`\nA server-initiated request frame (has both `method` and a non-null `id`) would be treated as a notification by `is_notification`.\n**Status:** Open\n\n## Skipped files\nNone.\n\n## Review notes\nFull-tier review, source surrounding code read for both files.\n\n**Reviewed through commit:** `23ffe0eb7`\n\n## Re-review log\n<no re-reviews yet>\n"
        }
      ]
    },
    {
      "id": 1,
      "name": "fix-and-clarify-new-finding",
      "prompt": "pr-19-review.md has a new finding I haven't dealt with yet — can you go through it and figure out what needs doing? This is for https://github.com/aurora-firmware/the-intern/pull/19. Don't touch GitHub.",
      "expected_output": "Since no reviewer or developer has weighed in on this specific finding (no matching GitHub comment exists), receive-pr-review can't apply a confident one-line fix for an unbounded wait — it triages this as either 'needs clarification' (e.g. asking whether callers already enforce a timeout at a higher layer, or whether the underlying socket read times out) or as a 'valid, large/ambiguous' finding describing what a real fix would require, without inventing a specific timeout duration or silently declaring it fixed. The report gets exactly one new annotation reflecting that decision, added under the existing finding text. No GitHub posts (not requested).",
      "files": [
        {
          "path": "pr-19-review.md",
          "content": "# PR Review: aurora-firmware/the-intern#19 — bob chat + admin_rpc improvements\n\n## Summary\n1 finding.\n\n| Scope | Files | Lines changed | Tier | Findings |\n|---|---|---|---|---|\n| source | 1 | 470 | full | 1 |\n\n## Findings\n### Source\n#### [warning] `Subscription::call` waits indefinitely for a matching response id — `the-intern/service/crates/bob/src/client/admin_rpc.rs:143`\n`call()`'s read loop has no timeout or cancellation — if the server never sends a response with the matching id, the awaiting caller hangs forever.\n**Status:** Open\n\n## Skipped files\nNone.\n\n## Review notes\nFull-tier review, source surrounding code read.\n\n**Reviewed through commit:** `23ffe0eb7`\n\n## Re-review log\n<no re-reviews yet>\n"
        }
      ]
    },
    {
      "id": 2,
      "name": "no-report-found",
      "prompt": "Can you go through the PR review feedback for https://github.com/cli/cli/pull/13619 and let me know what to do?",
      "expected_output": "receive-pr-review looks for pr-13619-review.md, doesn't find one, and tells the user there's nothing to triage — suggesting they run the pr-review skill first rather than fabricating findings from scratch or silently falling back to only reading GitHub comments.",
      "files": []
    },
    {
      "id": 3,
      "name": "opt-in-github-sync-draft-only",
      "prompt": "Go through pr-19-review.md for https://github.com/aurora-firmware/the-intern/pull/19 and draft replies to post on GitHub for anything unresolved once you're done — but don't actually post them yet, I want to review the drafts first.",
      "expected_output": "receive-pr-review triages the seeded finding (the Subscription::call timeout, same as eval 1) and, because GitHub sync was explicitly requested, drafts a reply for it alongside the local report annotation, then shows the draft to the user for review. It does not call the GitHub API to post anything, since the user explicitly asked to review before posting and no confirmation to post was given in this conversation — same read-only publish gate pr-review itself follows.",
      "files": [
        {
          "path": "pr-19-review.md",
          "content": "# PR Review: aurora-firmware/the-intern#19 — bob chat + admin_rpc improvements\n\n## Summary\n1 finding.\n\n| Scope | Files | Lines changed | Tier | Findings |\n|---|---|---|---|---|\n| source | 1 | 470 | full | 1 |\n\n## Findings\n### Source\n#### [warning] `Subscription::call` waits indefinitely for a matching response id — `the-intern/service/crates/bob/src/client/admin_rpc.rs:143`\n`call()`'s read loop has no timeout or cancellation — if the server never sends a response with the matching id, the awaiting caller hangs forever.\n**Status:** Open\n\n## Skipped files\nNone.\n\n## Review notes\nFull-tier review, source surrounding code read.\n\n**Reviewed through commit:** `23ffe0eb7`\n\n## Re-review log\n<no re-reviews yet>\n"
        }
      ]
    }
  ]
}
```

- [ ] **Step 2: Verify JSON validity**

Run:
```bash
python3 -c "
import json
d = json.load(open('plugins/github-utils/skills/receive-pr-review/evals/evals.json'))
assert d['skill_name'] == 'receive-pr-review'
assert len(d['evals']) == 4
assert [e['id'] for e in d['evals']] == [0, 1, 2, 3]
print('OK', len(d['evals']))
"
```
Expected: `OK 4`.

- [ ] **Step 3: Commit**

```bash
git add plugins/github-utils/skills/receive-pr-review/evals/evals.json
git commit -m "test: add evals for receive-pr-review"
```

---

### Task 6: Manifests and README

**Files:**
- Modify: `plugins/github-utils/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/github-utils/README.md`

**Interfaces:**
- Consumes: the skill name `receive-pr-review` from Task 4 and the re-review capability of `pr-review` from Task 2.
- Produces: nothing further downstream — this is the final task.

- [ ] **Step 1: Bump `plugin.json`**

In `plugins/github-utils/.claude-plugin/plugin.json`, find:

```json
{
  "name": "github-utils",
  "description": "Bundles GitHub CLI guidance, PR review workflows, issue creation, and changelog generation for Claude Code.",
  "version": "1.2.0",
```

Replace with:

```json
{
  "name": "github-utils",
  "description": "Bundles GitHub CLI guidance, PR review workflows (including re-review and a receive-pr-review response workflow), issue creation, and changelog generation for Claude Code.",
  "version": "1.3.0",
```

- [ ] **Step 2: Bump `marketplace.json`**

In `.claude-plugin/marketplace.json`, find:

```json
      "description": "GitHub CLI, pull request review, issue creation, and changelog generation skills bundled as a Claude Code plugin.",
      "version": "1.2.0",
```

Replace with:

```json
      "description": "GitHub CLI, pull request review (with re-review and receive-pr-review workflows), issue creation, and changelog generation skills bundled as a Claude Code plugin.",
      "version": "1.3.0",
```

- [ ] **Step 3: Update the README**

In `plugins/github-utils/README.md`, find:

```markdown
`github-utils` is a Claude Code plugin that bundles GitHub-focused skills:

- `gh-cli`
- `pr-review`
- `new-issue`
- `changelog`

## Skills

- `/github-utils:gh-cli`
- `/github-utils:pr-review`
- `/github-utils:new-issue`
- `/github-utils:changelog`
```

Replace with:

```markdown
`github-utils` is a Claude Code plugin that bundles GitHub-focused skills:

- `gh-cli`
- `pr-review`
- `receive-pr-review`
- `new-issue`
- `changelog`

## Skills

- `/github-utils:gh-cli`
- `/github-utils:pr-review`
- `/github-utils:receive-pr-review`
- `/github-utils:new-issue`
- `/github-utils:changelog`
```

- [ ] **Step 4: Verify manifests and README**

Run:
```bash
python3 -c "
import json
p = json.load(open('plugins/github-utils/.claude-plugin/plugin.json'))
m = json.load(open('.claude-plugin/marketplace.json'))
assert p['version'] == '1.3.0'
assert m['plugins'][0]['version'] == '1.3.0'
print('versions OK')
"
grep -q 'receive-pr-review' plugins/github-utils/README.md && echo README_OK
```
Expected: `versions OK`, then `README_OK`.

- [ ] **Step 5: Commit**

```bash
git add plugins/github-utils/.claude-plugin/plugin.json .claude-plugin/marketplace.json plugins/github-utils/README.md
git commit -m "chore: bump github-utils to 1.3.0 for receive-pr-review and re-review"
```
