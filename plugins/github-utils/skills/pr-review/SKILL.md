---
name: pr-review
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

# pr-review

Review an open GitHub pull request end to end: fetch, classify, size, review
with scoped agents, consolidate, report, and optionally publish. If a report
already exists for this PR, re-review it instead — see Step 0.

The goal is a **high-signal review**: a handful of findings a maintainer
would thank you for, not a wall of nitpicks. Every step below exists to
either focus attention (classification, tiering) or remove noise (filtering,
deduplication, the reasonableness pass). When in doubt, drop a finding —
a false positive costs the reader more trust than a missed suggestion.

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

Resolve the PR reference from the user's message (URL, `owner/repo#N`, bare
number against the current repo, or the current branch's PR). Then fetch:

```bash
gh pr view <N> --repo <owner>/<repo> --json number,title,body,author,state,url,baseRefName,headRefName,headRefOid,additions,deletions,changedFiles
gh api repos/<owner>/<repo>/pulls/<N>/files --paginate
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate   # existing review comments
```

The `/files` endpoint gives per-file `status`, `additions`, `deletions`, and
the `patch` (diff hunks) — this is the primary input for everything that
follows. Patches for very large files come back truncated or absent; fetch
those with `gh pr diff <N> --repo <owner>/<repo>` if needed.

Fetch existing review comments so the review doesn't repeat points a human
(or a previous run) already made — drop any finding that an existing comment
thread already covers.

If the PR is closed or merged, say so and ask whether to proceed anyway.

## Step 2 — Filter noise

Exclude these from review (they still appear in the report's "skipped" list
with a reason):

- Lock files: `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Cargo.lock`, `go.sum`, `poetry.lock`, `Gemfile.lock`, etc.
- Vendored code: `vendor/`, `node_modules/`, `third_party/`
- Minified assets (`*.min.js`, `*.min.css`) and source maps (`*.map`)
- Generated files (a `@generated` marker in the patch, protobuf/codegen output) — **except database migrations**, which are generated but high-risk and always reviewed
- Binary files (no patch available)

Don't silently drop anything else. A file that merely *looks* boring is not
noise.

## Step 3 — Classify by scope

Assign every remaining file exactly one **primary scope**:

| Scope | What belongs there |
|---|---|
| `ci` | `.github/workflows/`, CI configs (`.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `azure-pipelines.yml`), release/deploy automation, Dockerfiles used for CI |
| `documentation` | `*.md`, `docs/`, man pages, mdBook/Sphinx/Docusaurus sources, top-level README/CHANGELOG/LICENSE |
| `source` | Everything else: application code, tests, build manifests, app config |

Then mark files with a cross-cutting **security flag**, regardless of primary
scope, when they plausibly touch a trust boundary:

- Path contains `auth`, `crypto`, `secret`, `token`, `password`, `session`, `login`, `permission`, `acl`, `cert`, `tls`, `oauth`
- Workflow files that read `secrets.*`, change permissions/`GITHUB_TOKEN` scopes, or run on `pull_request_target`
- Dependency manifest changes that add or swap dependencies
- The patch itself adds credential handling, input parsing of untrusted data, command/SQL construction, or network listeners

The `security` scope is the set of security-flagged files. A flagged file is
reviewed **twice** — by its primary scope agent and by the security agent —
on purpose; the deduplication pass in Step 6 reconciles overlaps. Security is
a lens, not a file partition.

## Step 4 — Measure complexity per scope

For each non-empty scope, count its files and changed lines
(additions + deletions, after noise filtering) and assign a tier:

| Tier | Threshold | Review depth |
|---|---|---|
| `trivial` | ≤ 10 lines and ≤ 3 files | No agent — you review it inline yourself in Step 5 |
| `lite` | ≤ 100 lines and ≤ 10 files | Focused agent, works from the diff alone |
| `full` | anything larger | Thorough agent that also reads surrounding code for context |

The `security` scope is never `trivial`: if any file is security-flagged,
its tier is at least `lite`. A small diff in an auth path can still be an
account takeover.

Tiers exist to spend attention where it matters — a 4-line docs fix doesn't
need a spawned agent, and a 600-line source change reviewed from the bare
diff alone will miss bugs that only show up in the surrounding code.

## Step 5 — Review each scope

For `trivial` scopes: review the diff yourself, right now, applying the
relevant reference file's flag/don't-flag boundaries. Record findings in the
same format the agents use.

For `lite` and `full` scopes: spawn one subagent per scope, **all in the same
turn** so they run in parallel. Each agent prompt contains:

1. An instruction to first read the scope's reference file (give the absolute
   path, e.g. `<this skill's directory>/references/security.md`) — it defines
   what to flag, what not to flag, and how to behave per tier
2. PR context: repo, number, title, body, base/head branch
3. The scope's tier
4. The scope's file list with each file's patch hunks (paste them in — agents
   should not re-fetch the PR)
5. For `full` tier: how to read surrounding code — if the PR's repo is the
   repo checked out in the working directory, read files directly (fetch the
   PR head with `git fetch origin pull/<N>/head` if needed); otherwise use
   `gh api repos/<owner>/<repo>/contents/<path>?ref=<headRefOid>` with
   `-H "Accept: application/vnd.github.raw"`
6. The required output format (below)

Each agent returns its findings as a JSON array in its final message:

```json
[
  {
    "scope": "security",
    "severity": "warning",
    "file": "src/server/auth.rs",
    "line": 142,
    "title": "Token compared with non-constant-time equality",
    "body": "Explanation of the issue and why it matters, plus a concrete suggested fix.",
    "confidence": "high"
  }
]
```

`line` is the line number **in the new version of the file** (compute it from
the `@@ -a,b +c,d @@` hunk headers); for findings on deleted lines, set
`"side": "LEFT"` and use the old line number. Accurate line numbers matter:
they anchor the inline comments in Step 8. An empty array `[]` is a perfectly
good answer — agents must not invent findings to look useful.

If subagents are unavailable in the current environment, work through the
scopes yourself sequentially using the same reference files.

## Step 6 — Deduplicate and consolidate

You are now the coordinator. Take all findings (agents' plus your own
trivial-tier ones) and:

- **Deduplicate**: same file + same underlying issue → keep one copy, in the
  best-fitting scope (security-vs-source overlaps usually belong in security)
- **Recategorize**: a finding filed under the wrong scope moves, it isn't duplicated
- **Filter for reasonableness** — drop findings that are:
  - theoretical risks needing unlikely preconditions
  - about code this PR doesn't change
  - style preferences the surrounding code doesn't follow
  - "consider using library X" suggestions
  - already raised in the PR's existing review comments
- **Verify** anything marked low/medium confidence by reading the actual file
  content before keeping it

A typical healthy outcome is a small number of findings. Zero findings is a
legitimate result — say the PR looks good rather than manufacturing concerns.

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

Re-review additionally sets `Fixed (confirmed <date>)` once a fix is
verified, and `Acknowledged` once a `Won't Fix` or resolved
`Needs Clarification` is reconciled — see `references/re-review.md`. Only
re-review writes those two values; a developer's own annotation stays
within the four values above.

Don't add this block yourself on a first-time review — a finding with no
annotation is implicitly `Open`.

## Step 8 — Offer to publish

Show the user the report location and a one-line summary, then **ask**
whether to publish the findings to the PR as inline comments. Never publish
without explicit confirmation in the current session — publishing posts
content to GitHub under the user's account.

If the user confirms, read `references/publishing.md` and follow it: a single
review with `event: COMMENT` carrying all inline comments, anchored to the
diff. This skill never approves or requests changes — the verdict belongs to
humans.

## References

- `references/source-code.md` — source scope: flag/don't-flag boundaries
- `references/documentation.md` — docs scope: flag/don't-flag boundaries
- `references/ci.md` — CI scope: flag/don't-flag boundaries
- `references/security.md` — security scope: flag/don't-flag boundaries
- `references/publishing.md` — exact gh api calls for publishing inline comments (read only at Step 8)
- `references/re-review.md` — full re-review flow, read only when Step 0 finds an existing report
