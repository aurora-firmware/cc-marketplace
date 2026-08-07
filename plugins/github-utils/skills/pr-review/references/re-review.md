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
- Update **Re-review log**: replace the `<no re-reviews yet>` placeholder
  with your first entry; on later rounds, append below the existing
  entries instead:
  ```markdown
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
