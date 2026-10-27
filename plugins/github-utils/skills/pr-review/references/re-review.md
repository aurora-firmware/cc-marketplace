# Re-review mode

Followed when Step 0 finds an existing `pr-<number>-review.md` in the
working directory. Re-review only what changed since the last round instead
of repeating the full review — the report already has the findings and the
developer's response to them.

The loop ends only when reviewer and developer **agree on every finding**:

- a fixed finding is **`Fixed (confirmed)`** once the reviewer has verified
  the fix resolves the finding as written;
- a disputed finding is **`Acknowledged`** once the reviewer finds the
  justification demonstrates the finding doesn't hold;
- anything else is `Open`, with the reviewer saying why.

The test in both directions is evidence: don't close a finding out of
politeness or keep one open out of stubbornness. And the reviewer **never
suggests the fix** — when a fix or justification falls short, say what is
still not as it should be and why.

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
**Re-review log**. On the first re-review, that log has no entries yet
(it reads `<no re-reviews yet>`) — in that case, treat every GitHub
comment/review not already represented as a finding in the report as
relevant.

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

If the two SHAs are identical, there's no new diff — skip Step 7 (there's
nothing to review), but still run Steps 4–6 (reconciliation), since a
developer's annotations may have changed since the last round even without
new commits. Tell the user no new commits were found.

## 4. Reconcile findings marked `Fixed`

For each finding annotated `Status: Fixed`, verify the fix against the
**finding as written** — the developer's change may be real and still miss
the point. Read the current file at the finding's location (from the new
diff if it's in range, otherwise the current file content directly), and
re-check whatever the finding's **Basis** was measured against: re-run the
failing test or code path, re-read the claim or rule.

- The finding no longer holds → update to
  `**Status:** Fixed (confirmed <today's date>)`.
- The change isn't there (e.g. the cited commit isn't in this PR's commit
  range), or it doesn't resolve the finding, or it introduces a new
  discrepancy → revert to `**Status:** Open` and say what still isn't right
  and why, without prescribing the repair:
  ```markdown
  > **Developer:** Fixed in `a3f9c2d` — switched to `subtle::ConstantTimeEq`.
  > **Reviewer:** Reopened — the comparison in `verify_token()` at
  > `auth.rs:150` still uses `==`; only `verify_session()` changed.
  **Status:** Open
  ```
  A *new* discrepancy introduced by the fix is a new finding (Step 7), not a
  reopen.
- The developer corrected a claim (PR description, docs) instead of the
  code → valid when the corrected claim is now true and the change is still
  acceptable; verify both.

Never accept a `Fixed` claim on the developer's word alone.

## 5. Reconcile findings marked `Needs Clarification`

For each finding annotated `Status: Needs Clarification`, read the
developer's question and answer it directly, appended under their note.
Answer what was asked, without prescribing a repair:

```markdown
> **Developer:** Is this null case actually reachable given the queue only
> ever enqueues validated jobs?
> **Reviewer:** Yes — `retry_job()` re-enqueues without re-validating, so
> this path is reachable from the retry flow.
**Status:** Open
```

If the answer shows the finding was wrong (the developer's premise was
correct, or the reviewer misread the code), say so plainly and close it:
`**Status:** Acknowledged`.

## 6. Reconcile findings marked `Won't Fix`

A `Won't Fix` is a dispute. Judge the justification on its evidence. The
developer must have shown one of:

- **Misinterpretation** — the claim or rule doesn't say what the finding took
  it to say, or the code does something the reviewer misread (cite the code,
  test or doc that shows it);
- **Out of scope** — the issue exists but belongs to something the task
  didn't set out to change (the PR's stated scope and the unchanged
  surrounding code back this up);
- **Intentional and sanctioned** — a project rule, ADR or design doc
  explicitly requires the behavior.

Then decide:

- **Convinced** → `**Status:** Acknowledged`, with a reviewer note saying
  what in the justification settled it. The finding stays in the report as a
  record, not reopened.
- **Not convinced** → `**Status:** Open`, with a reviewer note saying what
  the justification doesn't address (a bare preference, an unverified
  assertion, evidence that doesn't touch the finding) and why the
  discrepancy stands. Engage with the developer's argument; don't repeat the
  finding.

Exception: `critical`-severity findings are never silently closed on a
developer's say-so. Even when convinced, leave the status as `Won't Fix`, add
a note flagging it for explicit human attention, and call this out
prominently in the summary you give the user at the end of the run.

**Stalemate:** if a finding has been disputed and rejected twice with no new
evidence on either side, stop trading notes. Mark it
`**Status:** Open`, add `> **Reviewer:** Escalated — needs a human decision.`
and put it in the end-of-run summary for the user.

## 7. Review the new diff

Run the normal classify → filter → tier → scope-agent flow (Steps 2–6 of
the main skill) — but only against the files/lines in the Step 3 diff, not
the whole PR. A file untouched since the last round doesn't get re-reviewed
just because it was part of the original PR.

Re-collect the claims and project rules first (Step 1b of the main skill —
the PR description may have changed) and re-verify the **Claims checked**
rows the new commits bear on. The no-fix rule applies to new findings too.

## 8. Update the report in place

- Refresh each reconciled finding's `Status` line (Steps 4–6 above).
- Append newly found issues (Step 7) under their scope's existing section,
  in the same finding format as a full review.
- Overwrite `**Reviewed through commit:**` with the new `headRefOid`.
- Update **Claims checked** for any claim whose result changed.
- Update **Re-review log**: replace the `<no re-reviews yet>` placeholder
  with your first entry; on later rounds, append below the existing
  entries instead:
  ```markdown
  - <date> @ `<headRefOid short>`: <N> fix(es) confirmed, <N> dispute(s)
    accepted, <N> reopened, <N> new finding(s) added, <N> awaiting developer
  ```
- State the agreement outcome to the user: **agreed** when every finding is
  `Fixed (confirmed ...)` or `Acknowledged` (nothing else is open and no new
  findings were added this round); otherwise list what is still open and
  whose move it is — the developer's (reopened or new findings, unanswered
  clarifications) or the user's (escalations, `critical` `Won't Fix`).

## 9. Publish gate

Same rule as the full review's Step 8: never post to GitHub without
explicit confirmation in the current session.

If confirmed:

- Post *only the newly found* findings (Step 7) as inline comments, same
  payload format as `references/publishing.md` (no suggested fixes).
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
