# Publishing findings to the PR

Read this only after the user has explicitly confirmed they want the
findings posted. Publishing creates a single PR review with `event: COMMENT`
(never `APPROVE` or `REQUEST_CHANGES`) whose inline comments appear in the
PR's "Files changed" tab.

## 1. Build the review payload

Write a `review.json`:

```json
{
  "commit_id": "<headRefOid from Step 1>",
  "event": "COMMENT",
  "body": "## pr-review findings\n\n<2-3 sentence summary; list here any findings that could not be anchored to a diff line>",
  "comments": [
    {
      "path": "src/server/auth.rs",
      "line": 142,
      "side": "RIGHT",
      "body": "**[warning] Token compared with non-constant-time equality**\n\n<finding body and suggested fix>"
    }
  ]
}
```

Rules for each comment:

- `path` is the file path relative to the repo root, exactly as it appears
  in the diff
- `line` + `side: "RIGHT"` for added/context lines (line number in the new
  file); `side: "LEFT"` with the old line number for findings on deleted
  lines
- For a multi-line range, add `start_line` (and `start_side`) for the first
  line of the range; `line` is the last
- **The line must be part of the diff.** GitHub rejects comments anchored to
  lines outside the patch hunks. If a finding points at an unchanged line
  far from the diff, don't force it — put it in the review `body` instead.
- Prefix each comment body with the severity in bold brackets, as above, so
  severities survive into the PR UI

## 2. Submit as one review

```bash
gh api repos/<owner>/<repo>/pulls/<N>/reviews --method POST --input review.json
```

One review, many comments — never a loop of single-comment API calls, which
spams notifications and the PR timeline.

## 3. Handle anchoring failures

A `422 Unprocessable Entity` almost always means one comment's `path`/`line`
isn't in the diff. The error does not say which comment. Recover by:

1. Re-checking each comment's line against the patch hunks (`@@ -a,b +c,d @@`
   — RIGHT-side anchors must fall within `c..c+d-1` of some hunk and the
   file must match)
2. Moving any comment you can't anchor into the review `body`
3. Re-submitting once

Do not retry blindly in a loop. If it still fails, post a review with all
findings in the `body` and no inline comments, and tell the user the inline
anchoring failed.

## 4. Confirm

Report the review URL from the API response back to the user.
