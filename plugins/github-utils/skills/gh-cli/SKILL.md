---
name: gh-cli
description: >
  Reference guide for the GitHub CLI (`gh`). Use this skill whenever the user
  asks about GitHub CLI commands, `gh` usage, interacting with GitHub from the
  terminal, automating GitHub workflows, using the GitHub REST or GraphQL API
  via `gh api`, managing PRs/issues/releases/runs from the command line, or
  scripting against GitHub. Trigger even if the user says something like "how
  do I check CI status", "list open PRs", "create a release from the terminal",
  "call the GitHub API", or "use gh outside of a repo" — these are all gh-cli
  tasks. If the user is using the `/pr-review` skill, this skill is a
  complementary reference for low-level `gh` commands.
---

# GitHub CLI (`gh`) Reference

`gh` brings GitHub to your terminal. It covers pull requests, issues, releases,
Actions, and raw REST/GraphQL API calls without leaving your shell.

- Installed version check: `gh --version`
- Official quickstart (auth + first commands):
  <https://docs.github.com/en/github-cli/github-cli/quickstart>
- Full manual: <https://cli.github.com/manual>

---

## Health Check

Run these after a fresh install or when something is unexpectedly failing:

```bash
gh --version                  # confirm binary is present
gh auth status                # show authenticated accounts + scopes
gh api user --jq '.login'     # end-to-end: token → real API call
```

If `gh auth status` shows no account, run `gh auth login` and follow the
interactive prompts (browser or paste a token).

---

## Getting More Information

Every command has a `--help` flag and built-in topic pages:

```bash
gh <command> --help
gh <command> <subcommand> --help

# built-in topic pages
gh help formatting        # --json / --jq / --template docs
gh help environment       # all GH_* env vars
gh help exit-codes        # 0=success 1=failed 2=cancelled 4=auth-required
gh help reference         # index of every command
```

---

## Most-Used Commands

```bash
# Pull Requests
gh pr list                                      # open PRs for current repo
gh pr create --fill --draft                     # open a draft PR from commits
gh pr checkout <number>                         # check out PR branch locally
gh pr view <number> --web                       # open in browser
gh pr checks <number>                           # CI status
gh pr review <number> --approve                 # approve
gh pr merge <number> --squash --delete-branch   # merge

# Issues
gh issue list --assignee "@me"
gh issue create --title "Bug: ..." --label bug
gh issue close <number>

# Repos
gh repo clone owner/repo
gh repo fork owner/repo --clone
gh repo view --web

# Actions
gh run list --limit 10
gh run watch <run-id>
gh run rerun --failed <run-id>

# Releases
gh release create v1.2.3 --generate-notes
gh release upload v1.2.3 ./dist/*

# Search
gh search prs --author "@me" --state open
gh search issues -- "memory leak -label:wontfix"   # -- before freeform query
```

---

## Core Workflows

### 1 — Auth & Health Check

```bash
# First-time setup
gh auth login                      # interactive: GitHub.com or GHE, HTTPS/SSH, browser/token
gh auth setup-git                  # configure git credential helper

# Managing multiple accounts
gh auth status                     # list all authenticated hosts/accounts
gh auth switch                     # choose active account
gh auth refresh --scopes repo,read:org   # add missing scopes without re-login
gh auth token                      # print the token in use (pipe to scripts)
```

**In CI (no interactive login):** set `GH_TOKEN` or `GITHUB_TOKEN` — `gh`
picks it up automatically; `GH_PROMPT_DISABLED=1` prevents prompts hanging.

---

### 2 — Pull Request Lifecycle

→ Create, review assignments, merge strategies, stacked PRs, automation: [`references/pr-workflows.md`](references/pr-workflows.md)

---

### 3 — Issue Management

→ Create, bulk triage, milestones, cross-repo transfers, automation: [`references/issue-workflows.md`](references/issue-workflows.md)

---

### 4 — CI / Actions Monitoring

```bash
# Latest run for the current branch
gh run list --branch "$(git branch --show-current)" --limit 1
```

→ Run monitoring, workflow dispatch, artifact downloads, secrets: [`references/actions-ci.md`](references/actions-ci.md)

---

### 5 — Repository Operations

```bash
gh repo clone owner/repo
gh repo fork owner/repo --clone --remote     # fork + clone + add upstream remote
gh repo create my-new-repo --public --source=.   # push existing local dir
gh repo view owner/repo                          # README + details
gh repo list myorg --limit 50 --json name,url
```

→ Releases, assets, attestation, changelogs, prerelease promotion: [`references/release-mgmt.md`](references/release-mgmt.md)

---

## Using `gh` Outside a Repository

Many commands infer owner/repo from the local git remote. When you're outside a
repo directory, supply it explicitly:

```bash
# -R / --repo flag (takes precedence over everything)
gh pr list -R owner/repo
gh issue create -R owner/repo --title "..."
gh run list -R owner/repo

# GH_REPO environment variable (useful when running a series of commands)
export GH_REPO=owner/repo
gh pr list
gh issue list
unset GH_REPO

# GH_HOST for non-github.com hosts
export GH_HOST=github.mycompany.com
gh api repos/{owner}/{repo}/releases
```

`gh repo set-default owner/repo` writes a default into `.git/config` for the
current directory — handy in monorepos or forks where the remote is not the
canonical repo.

---

## Direct API Usage

`gh api` wraps GitHub's REST v3 and GraphQL v4 APIs, automatically injecting
your auth token and resolving `{owner}`, `{repo}`, `{branch}` from the local
git context.

### REST

```bash
# GET (default)
gh api repos/{owner}/{repo}/releases

# POST / PATCH / DELETE
gh api -X POST repos/{owner}/{repo}/issues \
  -f title="New issue" \
  -f body="Details here" \
  -f assignees[]="@me"

# -f = string field   -F = typed (int, bool, null, @file)
gh api -X PATCH repos/{owner}/{repo}/issues/42 \
  -F state=closed
```

### GraphQL

```bash
gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) {
      issues(first:20, states:OPEN) {
        nodes { number title }
      }
    }
  }
' -f owner="{owner}" -f repo="{repo}"
```

### Output Shaping

`gh <cmd> --json` with no field list prints the available JSON fields for that command.

→ `--jq` filters, `--template` helpers, `--cache`, pagination, scripting patterns, rate-limit handling: [`references/api-advanced.md`](references/api-advanced.md)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `gh: command not found` | binary not on PATH | check install path; `which gh`; re-install |
| `authentication required` (exit 4) | no token / expired | `gh auth login` or set `GH_TOKEN` |
| `HTTP 403 Resource not accessible` | token missing scope | `gh auth refresh --scopes repo,read:org` |
| `HTTP 404` on valid endpoint | wrong repo or private repo without access | verify `-R owner/repo`; check token has `repo` scope |
| Interactive prompts hang in CI | tty detection | set `GH_PROMPT_DISABLED=1` and ensure `GH_TOKEN` is set |
| Wrong account used | multiple accounts | `gh auth status`; `gh auth switch` |
| SSL/cert errors on GHE | custom CA | `gh config set http.sslCABundle /path/to/ca.crt` |
| Output garbled in scripts | ANSI color codes | pipe to `| cat` or set `NO_COLOR=1` |
| Rate-limited (HTTP 429 / 403) | too many API calls | use `--cache`, batch requests, check `X-RateLimit-*` headers with `GH_DEBUG=1` |

**Enable debug output:**

```bash
GH_DEBUG=1 gh pr list           # verbose HTTP traffic
GH_DEBUG=api gh api user        # API-only debug mode
```

---

## Best Practices

**Scripting**

- Always use `--json` + `--jq` instead of parsing plain-text output — plain
  text format is not stable across `gh` versions.
- Check `gh`'s exit code (`$?`) in scripts; 0 = success, non-zero = failure.
  Use `set -e` or explicit checks.
- In CI, set `GH_TOKEN` via a secret and `GH_PROMPT_DISABLED=1` to prevent
  any blocking prompts.

**Token hygiene**

- Prefer fine-grained tokens over classic PATs — scope them to the minimum
  required repositories and permissions.
- Use `gh auth token` to retrieve a token in scripts rather than hard-coding
  it.
- Rotate tokens via `gh auth refresh` when scopes change.

**Performance**

- Use `--cache <duration>` on read-heavy API calls in scripts (e.g., `--cache 5m`).
- Use `--paginate` with `--slurp` when you need all pages as a single JSON
  array; avoid reimplementing pagination manually.
- `gh search` is faster than `gh issue list --repo` for cross-org queries.

**Ergonomics**

- Define aliases for frequent commands: `gh alias set co "pr checkout"`.
- `--web` opens any object in the browser — great when you need more context.
- `gh browse` opens the current repo (or a specific branch/file/commit).
- Install shell completions once: `gh completion -s zsh > ~/.zsh/completions/_gh`.

---

## Reference Files

For more complete usage scenarios, read the relevant file below:

| File | Contents |
|---|---|
| [`references/pr-workflows.md`](references/pr-workflows.md) | Full PR lifecycle: drafts, review assignments, merge strategies, stacked PRs |
| [`references/issue-workflows.md`](references/issue-workflows.md) | Bulk triage, milestones, project boards, cross-repo transfers |
| [`references/actions-ci.md`](references/actions-ci.md) | Workflow dispatch, artifact downloads, secrets, scheduled runs |
| [`references/release-mgmt.md`](references/release-mgmt.md) | Release assets, attestation, changelogs, prerelease promotion |
| [`references/api-advanced.md`](references/api-advanced.md) | REST pagination, GraphQL mutations, scripting patterns, rate-limit handling |
