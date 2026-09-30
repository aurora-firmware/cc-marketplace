# TypeScript language practices

## Compiler settings

Start every project from `strict: true` and add:

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,   // arr[i] and record[key] are T | undefined
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,       // forces `import type` for type-only imports
    "isolatedModules": true,
    "noEmit": true                      // typecheck only when a loader/bundler transpiles
  }
}
```

`exactOptionalPropertyTypes` is worth enabling in new code (it separates "absent" from "explicitly undefined") but expect churn in existing code; adopt it deliberately, not by default.

## Model with types

- Variants are **discriminated unions**, not optional-field bags.

```ts
type Result =
  | { kind: "ok"; value: string }
  | { kind: "error"; message: string };

function render(r: Result): string {
  switch (r.kind) {
    case "ok": return r.value;
    case "error": return `error: ${r.message}`;
    default: return assertNever(r);
  }
}

function assertNever(x: never): never {
  throw new Error(`Unhandled variant: ${JSON.stringify(x)}`);
}
```

- Prefer unions of string literals (or an `as const` object) over `enum`.

```ts
const Level = { Info: "info", Warn: "warn" } as const;
type Level = (typeof Level)[keyof typeof Level];
```

- Use `readonly` and `ReadonlyArray<T>` for data that should not be mutated; copy on write when a value may be shared.
- Use `satisfies` to check a value against a type without widening it: `const routes = {...} satisfies Record<string, Handler>`.
- Derive types from a single source of truth (`typeof`, `keyof`, `ReturnType`, a schema's `Static<>`) instead of maintaining a parallel interface.

## Boundaries: `unknown`, not `any`

Anything from outside the program (JSON, `process.env`, network, files, user input, `catch` bindings, tool or plugin inputs) is `unknown` until validated.

```ts
function isUser(v: unknown): v is { id: string; name: string } {
  return typeof v === "object" && v !== null
    && typeof (v as Record<string, unknown>).id === "string"
    && typeof (v as Record<string, unknown>).name === "string";
}
```

For anything larger than a couple of fields, use a schema validator (for example TypeBox or zod) and infer the type from the schema, so the runtime check and the static type cannot drift.

- `any` disables checking and spreads; if unavoidable, confine it to one line with a comment saying why.
- `as` is an unchecked claim. Prefer a type guard, a schema check, or `satisfies`. A double assertion (`as unknown as T`) is a red flag.
- Non-null assertion `!` is acceptable only right after a check the compiler cannot see, with the reason evident from the adjacent line. Otherwise handle the `undefined`.

## Null and undefined

- Use `?.` and `??`, not `||` (which also swallows `0`, `""`, `false`).
- Return `undefined`/`null` for "not found" or throw for "should exist"; pick one per API and say which.
- With `noUncheckedIndexedAccess`, narrow before using indexed values: `const first = items[0]; if (first === undefined) return;`.

## Generics

- Constrain them (`<T extends { id: string }>`); an unconstrained `T` that you then cast is a smell.
- Use as few type parameters as the signature needs; if a parameter appears once, it is probably unnecessary.
- Do not build conditional-type puzzles to save a few lines; prefer overloads or two functions when the caller-facing signature stays clearer.

## Async

- Every promise is awaited, returned, or explicitly marked `void` with a reason. Enable `@typescript-eslint/no-floating-promises` (or the Biome equivalent).
- Accept an `AbortSignal` in any operation that can outlive its caller, pass it to `fetch`, child processes, timers, and nested calls, and check `signal.aborted` between steps.

```ts
async function fetchJson(url: string, signal?: AbortSignal): Promise<unknown> {
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`GET ${url} failed: ${res.status}`);
  return res.json();
}
```

- Release resources in `try/finally` so cancellation and errors take the same path; make cleanup idempotent.
- `Promise.all` fails fast and leaves the others running; use `Promise.allSettled` when you need every outcome, and bound concurrency for large fan-out.
- Do not mix `await` in `forEach`; use `for...of` for sequential work or `Promise.all(items.map(...))` for parallel work.
- Attach timeouts with `AbortSignal.timeout(ms)` rather than racing a `setTimeout` that never clears.

## Errors

- Throw `Error` (or a subclass), never strings. Preserve the original with `cause`.

```ts
try {
  await save(doc);
} catch (err: unknown) {
  throw new Error(`could not save ${doc.id}`, { cause: err });
}
```

- `catch` bindings are `unknown`: narrow with `err instanceof Error` before reading `.message`.
- Do not swallow errors silently. If ignoring is right (best-effort logging, cleanup), say so in a comment and keep the `catch` narrow.
- Model expected failures in the return type (`Result`-style union) when callers must handle them; throw for programmer errors and unrecoverable states.

## Things to avoid

- `enum`, `namespace`, and parameter properties in code that runs through type-stripping loaders (they need runtime transformation that some loaders do not perform).
- Default exports for library-style modules (harder to rename and grep). Exception: a framework that requires one, such as a pi extension's factory.
- Barrel files that re-export everything; they hide dependencies and slow type checking.
- Overusing `Partial`/`Pick`/`Omit` chains where a named type would read better.
