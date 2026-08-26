# Issue body template

Reshape the issue's existing content into this structure. Preserve every
piece of information the original reporter gave — reproduction steps,
logs, suggested fixes — just move it under the matching heading. Never
delete reporter content to make it fit; if something doesn't map cleanly to
a heading, leave it under the closest one rather than dropping it.

```markdown
## Description

<One or two sentences: what's wrong and why it matters. Pull this from the
reporter's own summary if they gave one.>

## Expected Behavior

<What should happen.>

## Actual Behavior

<What happens instead. Include anything the reporter called out as a
secondary or related problem, even if it's out of scope for this fix — note
explicitly that it's out of scope rather than silently dropping it.>

## Steps to Reproduce

<Numbered steps, or the reporter's own repro if they gave one.>

## Logs / Evidence

<Command output, stack traces, diffs — whatever evidence exists.>

## Diagnosis

- **Root cause:** <from the fix contract>
- **Isolated fault:** `<file:line>` — <what's there and why it's wrong>
- **Planned fix:** <the minimal change>
- **Planned verification:** <the exact command(s) or manual steps that will
  confirm it>

## Status

<One line, updated as the workflow progresses:>
- `Diagnosis in progress.`
- `Fix in progress on branch \`fix/<N>-<short-description>\`.`
- `Fixed on branch \`fix/<N>-<short-description>\` — see PR #<M>.`
- `Merged in #<M>.`
```

## Filling in Diagnosis

Only write this section once Step 2 (diagnose) is complete — it should
never be aspirational or filled in before the root cause is actually known.
If reproduction wasn't possible and the fault is only a hypothesis, say so
explicitly (`**Root cause (hypothesis):**`) rather than presenting it as
confirmed.

## Filling in Status

This is the one line that gets edited again later in the workflow (Step 8,
after the PR opens; again on merge if the project doesn't auto-close). Every
other section should be stable once Step 3 first writes it — don't rewrite
Description/Expected/Actual/Repro/Logs on a later pass; only Diagnosis (if
new evidence emerges) and Status change.
