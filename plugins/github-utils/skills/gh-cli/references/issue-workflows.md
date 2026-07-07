# Issue Workflows — Full Reference

## Contents
1. [Creating issues](#creating-issues)
2. [Bulk triage](#bulk-triage)
3. [Milestones](#milestones)
4. [Cross-repo transfers](#cross-repo-transfers)
5. [Automation patterns](#automation-patterns)

---

## Creating Issues

```bash
# Basic
gh issue create --title "Bug: crash on startup" --label bug

# Full options
gh issue create \
  --title "feat: dark mode support" \
  --body "Users have requested dark mode. See discussion #100." \
  --label "enhancement,ux" \
  --assignee alice,bob \
  --milestone "v3.0" \
  --project "Product Backlog"

# From a template file
gh issue create --body-file .github/ISSUE_TEMPLATE/bug_report.md

# Open the creation form in browser
gh issue create --web
```

---

## Bulk Triage

```bash
# List with filters
gh issue list --state open --label bug --assignee "@me"
gh issue list --label "needs-triage" --json number,title,createdAt \
  --jq '.[] | "\(.number) \(.title)"'

# Bulk-label issues from a list of numbers
for n in 12 13 17 22; do
  gh issue edit $n --add-label "sprint-42"
done

# Bulk-assign
gh issue list --label "sprint-42" --json number --jq '.[].number' \
  | xargs -I{} gh issue edit {} --assignee "@me"

# Close all issues matching a label
gh issue list --label "wontfix" --json number --jq '.[].number' \
  | xargs -I{} gh issue close {}
```

---

## Milestones

`gh` can list and target milestones but cannot create them directly via the
CLI — use `gh api` for that:

```bash
# Create a milestone
gh api -X POST repos/{owner}/{repo}/milestones \
  -f title="v2.0" \
  -f description="Second major release" \
  -f due_on="2026-09-01T00:00:00Z"

# List milestones
gh api repos/{owner}/{repo}/milestones --jq '.[].title'

# Assign an issue to a milestone by its number
gh issue edit <issue-number> --milestone "v2.0"

# Close a milestone
MILESTONE_NUMBER=$(gh api repos/{owner}/{repo}/milestones \
  --jq '.[] | select(.title=="v2.0") | .number')
gh api -X PATCH repos/{owner}/{repo}/milestones/$MILESTONE_NUMBER \
  -f state=closed
```

---

## Cross-Repo Transfers

```bash
# Transfer an issue to another repo you have write access to
gh issue transfer <number> destination-owner/destination-repo
```

Note: labels, milestones, and assignees may not carry over if the destination
repo doesn't have matching labels/milestones. Create them first or re-apply
after transfer.

---

## Automation Patterns

```bash
# Find issues with no assignee
gh issue list --json number,title,assignees \
  --jq '.[] | select(.assignees | length == 0) | .number'

# Add a comment notifying a team
gh issue comment <number> --body "@myorg/team-name — please triage."

# Pin/unpin (visibility in issue list)
gh issue pin <number>
gh issue unpin <number>

# Lock / unlock (prevents new comments)
gh issue lock <number> --reason resolved
gh issue unlock <number>

# Link an issue to a PR (for "develop" branch)
gh issue develop <number> --name "fix/issue-42-crash"

# Search across all repos in an org
gh search issues --owner myorg --label bug --state open \
  --json number,repository,title --jq '.[] | "\(.repository.name)#\(.number) \(.title)"'
```
