---
name: fix-issue
description: >-
  End-to-end workflow for turning a specific open GitHub issue into a merged
  fix: fetches the issue, diagnoses the root cause before touching any code,
  rewrites the issue body into a structured template (Description, Expected
  Behavior, Actual Behavior, Steps to Reproduce, Logs/Evidence, Diagnosis,
  Status) with the diagnosis appended, branches off the repo's default
  branch as `fix/<issue-number>-<short-description>`, implements and
  verifies the minimal fix, opens a PR that links back to the issue, then
  hands off to the pr-review and receive-pr-review skills to close the
  loop. A lighter-weight alternative to a full internal bug-tracking
  process — no separate ticketing system, no doc trail beyond the issue and
  the PR themselves. Use whenever the user asks to fix, resolve, work, pick
  up, or ship a fix for one specific GitHub issue — "fix issue #57", "let's
  resolve this bug report", "pick up #12 and ship a fix for it", "work
  through this GitHub issue end to end", "diagnose and fix #90" — even if
  they don't name this skill directly. Not for triaging which issue to work
  on next (that's just gh-cli list/read), and not for feature requests or
  open-ended design work that needs exploration first — route those through
  the project's own planning or spec process instead. Defers to gh-cli for
  exact `gh` command syntax, and to pr-review / receive-pr-review for the
  review loop once a PR is open.
---

# fix-issue

Take one specific open GitHub issue from report to merged fix, without
standing up a separate ticketing/doc-trail system: the issue itself carries
the diagnosis, the branch and PR carry the fix, and `pr-review` /
`receive-pr-review` carry the review loop.

This skill covers the *workflow* — what order to do things in, what to
diagnose before coding, what template the issue body follows, and when to
stop and confirm with the user. For exact `gh` command syntax at every step,
use the `gh-cli` skill — this skill deliberately doesn't repeat that here.

**Scope check first:** this skill is for a fix — a bug, a small well-scoped
defect, a clearly-specified small task. If the issue is actually a feature
request or needs design exploration, say so and suggest the project's own
brainstorm/spec process instead of forcing it through this workflow.

## Step 1 — Fetch the issue

Resolve the issue the same way `pr-review` resolves a PR: a URL,
`owner/repo#N`, a bare number against the current repo, or a number the user
just named from a prior triage conversation.

```bash
gh issue view <N> --json number,title,body,labels,state,url
```

If the issue is already closed, or already has a linked PR, say so and ask
whether to proceed rather than assuming this is fresh work.

## Step 2 — Diagnose before touching any code

Do not write or edit implementation code in this step.

If the project has its own diagnosis/debugging skill (for example a `debug`
skill in its `.claude/skills/`), use it for this step and adapt its output
to the fix contract below instead of whatever lifecycle-file trail it
normally produces — this workflow keeps the diagnosis on the issue itself,
not in a separate file. Otherwise, follow this lightweight procedure:

1. **Reproduce or confirm** — run the failing case, or, when a live
   reproduction isn't practical, confirm the defect by reading the
   implicated code path directly and tracing the data through it. State
   which one you did.
2. **Isolate the fault** — the specific file, function, or line responsible.
3. **Identify the root cause** — not just the symptom. If only a hypothesis
   is supportable from available evidence, label it as one.
4. **Form the fix contract** — the four things Step 3 needs:
   - Root cause
   - Isolated fault (file:line)
   - Planned fix (the minimal change)
   - Planned verification (the test or manual step that will confirm it)

Do not broaden scope here — resist the urge to fix adjacent things noticed
along the way. Note them for a separate issue instead.

## Step 3 — Rewrite the issue body

Read `references/issue-template.md` and reshape the issue's existing content
into that structure — preserve the original reporter's information, just
reorganize it under the template headings — then append a `## Diagnosis`
section from Step 2's fix contract and a `## Status` line.

Show the user the drafted body before writing anything. Editing a GitHub
issue is visible to everyone with repo access, so **never push the edit
without explicit confirmation** in the current conversation — same rule
`new-issue` follows before creating an issue. If the user asks for changes,
revise and re-show.

Once confirmed, use the gh-cli skill for the exact syntax to update the
issue body.

## Step 4 — Branch

Check whether the project documents its own branch model (a `git-conventions`
skill, a CONTRIBUTING.md, a CLAUDE.md/AGENTS.md section) and follow that if
one exists — some projects branch fix work off an integration branch, not
the default branch directly.

Otherwise, the default convention: branch off the repository's default
branch, named `fix/<issue-number>-<short-description>` — a few hyphenated
words, not the full issue title.

Confirm the working tree is clean before branching.

## Step 5 — Implement the fix

Apply the planned fix from Step 2's fix contract. Keep the diff to what the
isolated fault requires — this is a fix, not a refactor pass.

## Step 6 — Verify

Run the project's own build/lint/test commands (check its CLAUDE.md/AGENTS.md
or README for the canonical ones). Prefer running the specific test(s) that
exercise the isolated fault before running the broader suite. Where a test
can't fully cover the behavior (a CLI flow, a generated file's content), add
a manual verification step and record exactly what you ran and observed.

## Step 7 — Commit

Follow the project's own commit-message convention if it documents one
(again, check for a `git-conventions` skill or CONTRIBUTING.md first).
Otherwise default to `<type>(<scope>): <description>` — imperative,
lowercase, no trailing period — and don't repeat the issue number in the
message; the branch name already carries it.

## Step 8 — Push and open the PR

Push the branch, then open a PR against the repository's default branch (or
whatever Step 4 identified as the real integration target). Use the gh-cli
skill for exact syntax. The PR body should:

- Summarize the fix in a couple of bullets.
- Link back to the issue for the full diagnosis rather than repeating it.
- Include the verification/test plan from Step 6.
- Reference the issue so it auto-closes on merge (`Fixes #<N>`), unless the
  project's convention is to close issues manually.

Then update the issue's `## Status` line (from Step 3) to point at the PR.

## Step 9 — Review and close the loop

Invoke the `pr-review` skill against the new PR. If it finds anything,
invoke `receive-pr-review` to triage the findings — fix what's valid and
small, describe what's valid but large, ask what's unclear, push back with
a reason on what's a disagreement — then re-run `pr-review` to confirm.
Report the final state (clean, or what's still open and why) to the user;
do not merge on the user's behalf.

## Quality Criteria

- Root cause is identified and recorded *before* any implementation code
  changes (Step 2 comes before Step 5, always).
- The issue's original report content is preserved, not deleted, when
  rewritten into the template.
- No GitHub-visible write (issue edit, PR creation) happens without the
  user seeing the draft and confirming first.
- The diff stays scoped to the isolated fault — no drive-by refactors.
- Verification is concrete: exact commands run and their outcome, not just
  "tests pass."

## Common Pitfalls

- **Skipping the scope check** — running this workflow on a feature request
  produces a rushed, under-designed "fix." Redirect those instead.
- **Fixing before diagnosing** — patching the symptom that's visible instead
  of the root cause identified in Step 2.
- **Assuming the default branch model** — some projects integrate fix
  branches somewhere other than their default branch; check first.
- **Silent GitHub writes** — editing the issue or opening the PR without a
  confirmation checkpoint the user could have redirected.
- **Re-diagnosing on receive-pr-review** — once Step 9 hands off, follow
  `receive-pr-review`'s own triage rules rather than re-deriving them here.

## References

- `references/issue-template.md` — the issue-body template and how to fill
  in its Diagnosis and Status sections.
