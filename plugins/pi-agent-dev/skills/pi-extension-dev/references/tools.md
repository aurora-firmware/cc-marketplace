# Designing tools

Judgment that complements `docs/extensions.md` (section "Tools"). Paths are relative to the installed pi package.

- Schema: TypeBox (`import { Type } from "typebox"`). For string enums use `StringEnum([...] as const)` from `@earendil-works/pi-ai`, **not** `Type.Union([Type.Literal(...)])` (breaks Google's API; stated in `examples/extensions/README.md`).
- Result: `{ content: [{ type: "text", text }], details }`. `details` is required (use `undefined` or `{}` when none). It is what renderers and branch-aware state read.
- **Errors: throw.** Returning an object, even one whose text says "Error", does not mark the result as failed (`docs/extensions.md`).
- **Truncate large output** with `truncateHead` / `truncateTail` and `DEFAULT_MAX_BYTES` / `DEFAULT_MAX_LINES`, say so in the tool description, save the full output to a file, and tell the model where it is (`examples/extensions/truncated-tool.ts`).
- Shared mutable in-memory state → `executionMode: "sequential"` (`examples/extensions/tic-tac-toe.ts`). File mutations → wrap the whole read-modify-write in `withFileMutationQueue()`.
- `terminate: true` ends the run after the batch only if every completed tool in the batch agrees (`examples/extensions/structured-output.ts`).
- Give tools a `promptSnippet` and `promptGuidelines` when the model must learn when to use them; custom tools are omitted from the default "Available tools" section without a snippet (`examples/extensions/dynamic-tools.ts`).
- Optional tools: register all, keep some inactive, activate with `pi.setActiveTools()` (unknown names are ignored). Tool changes may invalidate the provider's cached prefix, so do not toggle per turn.
- Overriding a built-in: register a tool with the same name (`examples/extensions/tool-override.ts`); omit renderers to keep the built-in rendering.
- Nested model calls: `ctx.modelRegistry.streamSimple()`, and include `usage` in the result so session totals stay right.
