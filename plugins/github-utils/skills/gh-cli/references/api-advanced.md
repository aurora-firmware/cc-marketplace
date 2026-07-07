# API Advanced Usage — Full Reference

## Contents
1. [REST pagination](#rest-pagination)
2. [GraphQL mutations](#graphql-mutations)
3. [Output shaping (jq, templates)](#output-shaping)
4. [Scripting patterns](#scripting-patterns)
5. [Rate-limit handling](#rate-limit-handling)

---

## REST Pagination

GitHub's REST API returns at most 100 items per page. `--paginate` follows
`Link` headers automatically.

```bash
# Fetch ALL open issues (combines all pages)
gh api --paginate repos/{owner}/{repo}/issues?state=open \
  --jq '.[].title'

# --slurp wraps every page into a single top-level array
# (useful when downstream tools expect one JSON array)
gh api --paginate --slurp repos/{owner}/{repo}/commits \
  | jq 'length'

# Per-page size (max 100)
gh api "repos/{owner}/{repo}/issues?per_page=100&page=1"

# Paginate through search results
gh api --paginate "search/issues?q=repo:{owner}/{repo}+is:open+label:bug" \
  --jq '.items[].number'
```

**Caveat:** `--paginate` stops when the `Link: rel="next"` header is absent.
For search endpoints, the total can be > 1000 — use `search/issues` with
`sort` and `order` to prioritise and page within the cap.

---

## GraphQL Mutations

```bash
# Add a label to an issue via GraphQL
gh api graphql -f query='
  mutation($id:ID!, $labelIds:[ID!]!) {
    addLabelsToLabelable(input:{labelableId:$id, labelIds:$labelIds}) {
      labelable { ... on Issue { number } }
    }
  }
' -f id="<issue-node-id>" -f labelIds[]="<label-node-id>"
```

Get node IDs (GraphQL global IDs) via REST:

```bash
gh api repos/{owner}/{repo}/issues/42 --jq '.node_id'
gh api repos/{owner}/{repo}/labels/bug --jq '.node_id'
```

Common mutations:

```bash
# Close an issue via GraphQL
gh api graphql -f query='
  mutation($id:ID!) {
    closeIssue(input:{issueId:$id}) { issue { number state } }
  }
' -f id="<node-id>"

# Add a PR review comment on a specific line
gh api graphql -f query='
  mutation($prId:ID!, $body:String!, $path:String!, $line:Int!) {
    addPullRequestReviewThread(input:{
      pullRequestId:$prId,
      body:$body,
      path:$path,
      line:$line,
      side:RIGHT
    }) { thread { id } }
  }
' -f prId="<pr-node-id>" -f body="Nit: typo here" \
  -f path="src/main.rs" -F line=42
```

---

## Output Shaping

### `--jq`

`gh api` has built-in jq — the `jq` binary is not required.

```bash
# Extract nested field
gh api repos/{owner}/{repo}/releases/latest --jq '.tag_name'

# Filter array
gh api repos/{owner}/{repo}/issues \
  --jq '.[] | select(.labels[].name == "bug") | .number'

# Construct custom object
gh pr list --json number,title,author \
  --jq '.[] | {pr: .number, by: .author.login, title}'
```

### `--template` (Go templates)

```bash
# Table output with aligned columns
gh issue list --json number,title,state \
  --template '{{range .}}{{tablerow .number .title .state}}{{end}}{{tablerender}}'

# Time formatting helpers
gh pr list --json number,createdAt \
  --template '{{range .}}{{.number}} ({{timeago .createdAt}}){{"\n"}}{{end}}'

# Color
gh pr list --json number,state \
  --template '{{range .}}{{.number}} {{color "green" .state}}{{"\n"}}{{end}}'
```

Available helpers: `tablerow`, `tablerender`, `timeago`, `timefmt`, `color`,
`autocolor`, `pluck`, `join`, `truncate`, `hyperlink`.

---

## Scripting Patterns

**Check exit code:**

```bash
if gh pr merge "$PR" --squash --delete-branch; then
  echo "Merged"
else
  echo "Merge failed (exit $?)" >&2
fi
```

**Retrieve a secret token for use in a script:**

```bash
TOKEN=$(gh auth token)
curl -H "Authorization: Bearer $TOKEN" https://api.github.com/user
```

**Suppress color and interactivity in pipelines:**

```bash
NO_COLOR=1 GH_PROMPT_DISABLED=1 gh pr list --json number,title
```

**Caching in tight loops:**

```bash
# Cache org member list for 5 minutes while iterating
for repo in $(gh repo list myorg --json name --jq '.[].name'); do
  gh api --cache 5m orgs/myorg/members --jq '.[].login'
done
```

**Using `gh api` as a curl replacement:**

```bash
# Any REST endpoint, including undocumented ones
gh api /zen                              # GitHub's wisdom endpoint
gh api /rate_limit --jq '.rate'          # check rate limit status
gh api /repos/{owner}/{repo}/traffic/views   # repo view stats
```

---

## Rate-Limit Handling

GitHub enforces:
- **REST API**: 5000 requests/hour for authenticated users (higher for GitHub Apps)
- **GraphQL API**: 5000 points/hour
- **Search API**: 30 requests/minute

```bash
# Check current limit
gh api /rate_limit --jq '.rate | {limit, remaining, reset}'

# Enable HTTP-level debug to see rate-limit headers
GH_DEBUG=api gh api repos/{owner}/{repo}/issues 2>&1 | grep -i rate

# Use --cache to avoid redundant calls
gh api --cache 5m repos/{owner}/{repo}/topics

# When automating bulk operations, add a small sleep between API calls
for n in $(gh issue list --json number --jq '.[].number'); do
  gh issue edit "$n" --add-label sprint-42
  sleep 0.2    # ~5 req/sec, well within limits
done
```

If you hit a secondary rate limit (HTTP 429 or 403 with a `Retry-After`
header), back off for the indicated number of seconds before retrying.
