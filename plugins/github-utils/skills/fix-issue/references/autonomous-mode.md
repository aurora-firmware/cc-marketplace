# Autonomous mode

Read this when autonomous mode was explicitly requested — a background
agent, a scheduled job, or a caller who asked for it directly ("fix #N
autonomously", "run this without stopping to ask", an unattended context).
**Never assume it.** Without an explicit request, run interactively as
`SKILL.md` describes by default, and you don't need this file.

Autonomous mode governs the whole workflow, including the triage in
`references/choosing-an-issue.md`, which also has a mode-specific outcome.

## What changes

- **Skip every "show the draft and confirm" checkpoint** in `SKILL.md`
  (Step 3's issue edit, Step 8's PR body, and the matching Quality
  Criteria rule) — draft, then act immediately. Every write still gets
  reported as it happens; only the pause is removed, not the transparency.
- **Replace every other "ask the user" moment** in `SKILL.md` — Step 1's
  closed-issue/existing-PR check, the scope check, and Step 9's
  `Needs Clarification`/`Won't Fix` stopping condition — with one of the
  two escalation conditions below. There is no third option: nothing gets
  guessed past silently.
- **A stale diagnosis is not itself a reason to escalate.** If Step 2's
  diagnosis turns out incomplete or wrong once re-checked against the
  current code, re-analyze it, record the corrected diagnosis, and
  continue. Only escalate if the corrected diagnosis itself lands on
  condition 2.
- **"Do not merge on the user's behalf" (Step 9) holds regardless of
  mode.** Autonomous mode changes who gets asked mid-workflow, not this
  boundary. A caller that wants the result merged automatically once clean
  must say so and do it as an explicit step of its own, outside this
  skill.

## Escalation conditions

Stop immediately, leave whatever's already committed, pushed, or opened
exactly as it is — no rollback, no destructive cleanup — and report the
stage reached, which condition triggered, and the current state of the
repo, branch, PR, and issue.

1. **The environment isn't what this workflow expects.** A dirty working
   tree, a target branch that won't fast-forward or reach cleanly, a
   branch or open PR for this issue that already exists, `gh` not
   authenticated or pointed at the wrong repo, a git operation that fails
   unexpectedly (push rejected, merge conflict), or a failing or
   unresolvable CI check.
2. **The fix — or a review finding about it — needs a design decision or a
   human judgment call, not a bounded, mechanical resolution.** The issue
   is really a feature request or needs exploration (the scope check in
   `SKILL.md`), a diagnosis keeps landing on multiple valid approaches with
   no single obviously correct one, an implementation attempt isn't
   converging after reasonable retries, or a review finding is a
   `Won't Fix` call or an unresolved `Needs Clarification`.

## Common pitfalls

- **Assuming autonomous mode by default** — it's opt-in; without an
  explicit request for it, run interactively.
- **Escalating on a diagnosis that's merely stale** — re-analyze and
  correct it, then continue; only escalate if the corrected diagnosis
  itself needs a design decision (condition 2).
- **Letting autonomous mode merge** — "do not merge on the user's behalf"
  is unconditional; autonomous mode only changes who gets asked
  mid-workflow, never this boundary.
