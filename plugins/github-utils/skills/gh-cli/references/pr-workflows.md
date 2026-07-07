# PR Workflows — Full Reference

## Contents
1. [Creating PRs](#creating-prs)
2. [Review assignments](#review-assignments)
3. [Merge strategies](#merge-strategies)
4. [Stacked PRs](#stacked-prs)
5. [Automation patterns](#automation-patterns)

---

## Creating PRs

```bash
# Minimal — title + body from last commit
gh pr create --fill

# Full options
gh pr create \
  --title "feat(auth): add JWT refresh" \
  --body "Closes #42. Adds silent refresh on 401." \
  --base main \
  --label enhancement \
  --reviewer alice,bob \
  --assignee "@me" \
  --milestone "v2.0" \
  --draft

# From a template (file path to a markdown file)
gh pr create --body-file .github/pull_request_template.md
```

**Useful flags:**
- `--fill` — populate title/body from commits on the branch
- `--fill-verbose` — like `--fill` but includes the full commit list
- `--draft` / `--ready` — toggle draft state
- `--no-maintainer-edit` — prevent maintainer edits (for forks)

---

## Review Assignments

```bash
# Request / remove reviewers
gh pr edit <number> --add-reviewer alice,myorg/team-name
gh pr edit <number> --remove-reviewer bob

# Submit a review
gh pr review <number> --approve
gh pr review <number> --request-changes --body "Please add tests."
gh pr review <number> --comment --body "Minor nit: rename the variable."

# View all reviews
gh pr view <number> --json reviews --jq '.reviews[] | {author: .author.login, state}'
```

---

## Merge Strategies

```bash
# Squash (recommended for feature branches — clean history)
gh pr merge <number> --squash --delete-branch

# Merge commit (preserves branch history)
gh pr merge <number> --merge --delete-branch

# Rebase (linear history, individual commits)
gh pr merge <number> --rebase --delete-branch

# Auto-merge (merges when all checks pass)
gh pr merge <number> --squash --auto

# Disable auto-merge
gh pr merge <number> --disable-auto
```

When `--delete-branch` is used, the remote branch is deleted immediately
after merge. The local branch is not deleted — run `git branch -d <branch>`
separately if needed.

---

## Stacked PRs

`gh` does not natively manage stacked PR chains, but the `-B/--base` flag
lets you target any branch as the base:

```bash
# Chain: main ← feature/base ← feature/top
git checkout -b feature/base main
# ... commits ...
gh pr create --base main --title "Base layer"

git checkout -b feature/top feature/base
# ... commits ...
gh pr create --base feature/base --title "Top layer"
```

After the base PR merges, retarget the top PR:

```bash
gh pr edit <top-number> --base main
```

---

## Automation Patterns

```bash
# List all open PRs as JSON for processing
gh pr list --json number,headRefName,author,createdAt \
  --jq '.[] | select(.author.login == "dependabot[bot]")'

# Bulk-approve Dependabot PRs
gh pr list --author "app/dependabot" --json number --jq '.[].number' \
  | xargs -I{} gh pr review {} --approve

# Wait until a PR's checks all pass, then merge
gh pr checks <number> --watch && gh pr merge <number> --squash --delete-branch

# Add a comment with a template
gh pr comment <number> --body-file .github/review_checklist.md

# Convert draft to ready-for-review
gh pr ready <number>

# Revert a merged PR (creates a revert PR)
gh pr revert <number>
```
