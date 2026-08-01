---
name: new-issue
description: >
  Create a new GitHub issue (bug report, feature request, or task) end to
  end: gathers the issue details, priority, and project assignment from the
  user, shapes the issue body using the right structure, resolves it against
  the repo's real issue types/labels and the chosen project's fields, and
  creates it via `gh` only after the user confirms the draft. Use whenever
  the user asks to file, open, or create a GitHub issue, report a bug,
  request a feature, or track a task — e.g. "file a bug for this crash",
  "open an issue for dark mode support", "create a task for the migration",
  "create a github issue". For exact `gh` command syntax at every step, this
  skill defers to the gh-cli skill rather than repeating it.
---

# new-issue

Guide the user through creating a well-structured GitHub issue — bug report,
feature request, or task — and create it with `gh` once they've confirmed
the draft.

This skill covers the *workflow*: what information to gather, how to shape
each issue type, and when to check with the user before writing to GitHub.
For the exact `gh` command syntax needed at each step below, use the
`gh-cli` skill — this skill deliberately doesn't repeat that here.

## Step 1 — Gather information

Ask the user for:

- **Type** — bug, feature, or task
- **Target repo** — default to the repo in the current working directory; if
  there isn't one, or the user names a different repo, ask for `owner/repo`
- **Project** (optional) — use the gh-cli skill to look up the real Projects
  available for the target repo/org, present the list, and let the user pick
  one or skip
- **Priority** — critical, high, medium, or low. GitHub has no native
  Priority field on an issue itself — priority lives on a Project's custom
  field. It's only set if the chosen project exposes a matching field (see
  Step 3). Never write priority into the issue body or attach it as a label.

Only ask for what the user hasn't already told you.

## Step 2 — Branch on type

- Bug → read `references/bug.md` and follow it to shape the issue
- Feature → read `references/feature.md` and follow it to shape the issue
- Task → read `references/task.md` and follow it to shape the issue

Each reference file describes what to ask the user next and how to structure
the resulting issue body.

## Step 3 — Resolve type and priority against real GitHub metadata

Use the gh-cli skill to check what the target repo/org actually supports:

- **Type** — GitHub's native Issue Types (Bug, Feature, Task, or custom
  ones) are a separate concept from labels. If the repo/org has issue types
  configured, set the issue's type directly to the closest match. If not,
  fall back to a label (`bug`, `enhancement`, `task`, or whatever the repo
  actually uses) — only apply a label that exists; issue creation fails
  outright on an unknown one.
- **Priority** — only applies if a project was chosen in Step 1. Look up
  that project's fields; if it has a Priority-like field, map the user's
  answer to the closest option and set it once the issue is added to the
  project. If there's no project, or the project has no such field, tell the
  user priority can't be attached anywhere structured and confirm whether to
  proceed without recording it — don't fall back to putting it in the body
  or as a label.

## Step 4 — Draft and confirm

Assemble the full issue — title, body, type/label, project — and show the
complete draft to the user, including how priority will (or won't) be
recorded. Creating a GitHub issue is visible to everyone with repo access,
so **never create it without explicit confirmation** in the current
conversation. If the user asks for changes, revise and re-show the draft.

## Step 5 — Create the issue

Once confirmed, use the gh-cli skill to create the issue with the gathered
title, body, and type/label. If a project was chosen, add the issue to it
and set the Priority field when Step 3 found one. Report back the created
issue's number and URL.

## References

- `references/bug.md` — what to gather and how to structure a bug issue
- `references/feature.md` — what to gather and how to structure a feature issue
- `references/task.md` — what to gather and how to structure a task issue
