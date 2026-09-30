---
name: typescript-best-practices
description: >-
  TypeScript language practices and coding guidelines for writing and reviewing
  TypeScript: strict compiler settings, narrowing over assertions, discriminated
  unions, validating unknown input at boundaries, async and AbortSignal
  cancellation, error handling, ESM import rules, module structure, tooling,
  test conventions, and a review checklist. Includes the constraints of code
  loaded through jiti (such as pi extensions), which transpiles without type
  checking. Use whenever writing, reviewing, refactoring, or configuring
  TypeScript (tsconfig, types, generics, async code, Node/ESM projects), even
  when the user only says "clean this up" or "review this .ts file".
---

# TypeScript best practices

Two references, read what the task needs:

- `references/language.md`: how to use the type system and async/error features well.
- `references/guidelines.md`: project conventions: structure, naming, imports, tooling, tests, the review checklist, and running under `jiti`.

## Writing TypeScript

1. Read the project's existing `tsconfig.json`, formatter, linter, and test setup first. **The project's conventions win** over anything here; only fill gaps.
2. Model the data with types before writing logic: unions for variants, `readonly` for data that should not change, `unknown` for anything from outside.
3. Narrow instead of asserting. If you write `as`, `!`, or `any`, you owe a one-line reason.
4. Make cancellation and cleanup explicit in every async API you add.
5. Typecheck (`tsc --noEmit`) before claiming the work is done; a passing runtime is not evidence of type soundness when a loader such as `jiti` skips type checking.

## Reviewing TypeScript

Apply the checklist at the end of `references/guidelines.md`. Report findings by severity, each with the file and line, the risk, and the concrete fix. Do not flag pure style points the project's formatter or linter already enforces.

## When asked about tooling

Recommend, do not impose: keep what the project already uses. For a new project the guidelines propose a default set, marked as a proposal.
