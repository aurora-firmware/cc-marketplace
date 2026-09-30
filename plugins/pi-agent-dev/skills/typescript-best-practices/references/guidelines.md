# TypeScript coding guidelines

The project's existing conventions always win. Everything marked "Proposal" is a default for new code, not a rule.

## Module and file structure

- One responsibility per file; split when a file needs a "and" to describe it or grows past what you can hold in your head.
- Separate pure logic from framework glue. Put decision logic in a plain module with no framework imports so it can be unit tested without the host. (Example: pi's `examples/extensions/plan-mode/` keeps `isSafeCommand` and step extraction in `utils.ts`, apart from the extension wiring in `index.ts`.)
- Keep side effects (I/O, timers, process spawning) at the edges; pass dependencies in rather than importing singletons in deep modules.
- Export the minimum; internal helpers stay unexported.

## Naming

- Types and classes `PascalCase`; values, functions, and variables `camelCase`; constants `SCREAMING_SNAKE_CASE` only for true module-level constants.
- Name booleans as questions (`isReady`, `hasUI`), functions as verbs, and avoid encoding types in names.
- No abbreviations a new reader would have to look up.

## Imports and modules (ESM)

- Use `import type { X }` for type-only imports (enforced by `verbatimModuleSyntax`).
- Use the `node:` prefix for built-ins (`node:fs/promises`).
- Match the resolution mode in use. Under Node's ESM resolution, relative imports need explicit file extensions. Loaders that run TypeScript directly (including the examples shipped with pi) import siblings with a `.ts` extension, which needs `allowImportingTsExtensions` when you typecheck with `noEmit`.
- Set `"type": "module"` in `package.json` for ESM packages.
- No circular imports; if two modules need each other, extract the shared piece.

## Error handling style

- Fail early at boundaries: validate input where it enters, then work with trusted types.
- Error messages say what failed and with what input, without leaking secrets.
- One place decides how errors surface to the user (log, notify, exit code); lower layers throw.

## Tooling

Follow what the project has. For a new project, the following is a proposal:

- **Typecheck:** `tsc --noEmit` as a `check`/`typecheck` script, run in CI and before commits.
- **Format and lint:** pick one setup and record it: Biome (single tool) or ESLint plus Prettier. Turn on a no-floating-promises rule and a no-explicit-any rule.
- **Tests:** Vitest (`vitest --run`) for unit tests; it runs TypeScript directly and mirrors what the pi project itself uses for its own tests.
- **Package manager and Node version:** commit the lockfile, and declare `engines.node`.

## Test conventions

- Test behavior through the public function, not private helpers.
- One assertion concept per test; name tests after the behavior (`rejects_empty_input`), not the function.
- Cover the boundary cases: empty input, `undefined`/`null`, the largest allowed size, cancellation (`AbortSignal` already aborted), and error paths.
- Fake time and I/O at the edge; keep pure logic tested with plain values.
- A type-level guarantee that matters gets a test too (`// @ts-expect-error` for calls that must not compile).

## Running under `jiti` (for example pi extensions)

Some hosts load `.ts` files through `jiti`, which transpiles TypeScript **without type checking**. Consequences:

- Type errors never surface at load. Run `tsc --noEmit` yourself (a `typecheck` script) with the host's packages installed as dev dependencies so its types resolve.
- Anything needing more than type stripping (`enum`, `namespace`) is riskier; use unions of literals.
- Keep `"type": "module"`. Runtime dependencies go in `dependencies`; packages the host supplies at runtime go in `peerDependencies` (`"*"`) and are not bundled.
- Use `import type` so the loader never tries to resolve a type-only import at runtime.
- Do a real load smoke test after typechecking; the type checker cannot see runtime resolution problems.

## Review checklist

Severity in brackets. For each finding give file:line, the risk, and the fix.

- [High] Unvalidated external data typed as a concrete type (`JSON.parse(...) as T`, `process.env.X as string`).
- [High] Floating or unhandled promises; missing `await` in `try/catch`; swallowed errors.
- [High] Long-running or cancellable work without `AbortSignal` propagation; resources not released in `finally`.
- [High] Shared mutable state mutated from concurrent code.
- [Medium] `any`, `as`, or `!` without a justification.
- [Medium] Optional-field bags where a discriminated union fits; missing exhaustive `default: assertNever`.
- [Medium] `||` used for defaults where `0`/`""`/`false` are valid values.
- [Medium] `catch (e)` reading `e.message` without narrowing.
- [Medium] Missing tests for empty input, error paths, or cancellation.
- [Low] Type-only imports without `import type`; missing `node:` prefix; barrel re-exports; default exports where none are required.
- [Low] Parallel interface that duplicates a schema or existing type.
