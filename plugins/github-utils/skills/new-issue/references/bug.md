# Bug Issue — Reference

Use this once Step 1 of the main skill (type, repo, project, priority) is
done and the type is "bug".

## What to gather

1. **Expected behavior** — ask what the user expected to happen.
2. **Actual behavior** — ask what actually happens instead. The gap between
   this and the expected behavior is the bug — be specific about it, not
   just "it doesn't work."
3. **Reproduction steps** — ask for the minimal steps to reproduce it,
   numbered in order. If the user isn't sure, help narrow it down
   (environment, recent changes, how consistently it reproduces).
4. **Logs** — ask if there are any logs, stack traces, or error output.
   Include them verbatim in a fenced code block if provided. Don't fabricate
   logs or a stack trace if the user doesn't have one — omit that section
   instead.

Priority is gathered and resolved in the main skill's Step 1/3 — it belongs
in the GitHub Priority field, never in this body.

## Issue body structure

```markdown
## Expected Behavior
<what should happen>

## Actual Behavior
<what happens instead>

## Steps to Reproduce
1. ...
2. ...
3. ...

## Logs
<fenced code block with logs/stack trace, or omit this section entirely if none were provided>
```

Title convention: `Bug: <short description>`.
