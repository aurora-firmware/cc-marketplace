# Choosing the issue, when none was given

Read this when the caller invoked the skill without naming a specific
issue — no URL, no `owner/repo#N`, no bare number, nothing from a prior
conversation to resolve. If an issue was named, skip this entirely and go
straight to Step 1 in `SKILL.md`.

Triage runs **the same way regardless of mode** (interactive or
autonomous) — nothing in the triage itself pauses to ask. Only the outcome
when nothing suitable survives differs by mode (step 5 below).

1. `gh issue list --state open --json number,title,labels,updatedAt`, then
   read full bodies for anything plausibly a bug.
2. Exclude:
   - Anything that's really a feature request or needs design exploration
     (the scope check in `SKILL.md`, applied per candidate).
   - Issues stuck in an unresolved reopen/dispute loop — read the comment
     thread; a prior triage pass may have closed and reopened it with
     disagreement never settled.
   - Issues that already have an open PR or a matching `fix/<N>-...`
     branch.
3. Rank what survives, in order: a confirmed root cause over one still a
   hypothesis; an isolated, single-purpose fix over one needing a design
   decision between multiple valid approaches; higher recurrence/impact
   over a one-off.
4. Pick the top-ranked issue. A tie is not a reason to stop or ask — break
   it by lowest issue number and proceed.
5. If nothing survives step 2's exclusions, no suitable issue was found:
   - **Autonomous mode:** stop and report that no eligible issue exists —
     an empty result, not a failure, but nothing to hand off to Step 1.
     (See `references/autonomous-mode.md`.)
   - **Interactive mode:** ask the user how to proceed (broaden the
     filters, point at a specific issue directly, or something else) —
     there's someone to ask, so this doesn't silently stop.

Otherwise, continue to Step 1 in `SKILL.md` with the issue this picked.

## Common pitfall

**Asking the user to pick among the viable candidates** — don't. Triage
picks the top-ranked issue itself in both modes; only an empty result
(nothing survives the exclusions) asks in interactive mode, or stops in
autonomous mode.
