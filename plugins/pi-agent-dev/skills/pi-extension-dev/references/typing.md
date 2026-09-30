# Typing patterns for pi extensions

General TypeScript guidance lives in the `typescript-best-practices` skill; these are the pi-specific patterns. Paths are relative to the installed pi package.

- Use `defineTool({...})` for tools assigned to a variable or array, so parameter types are inferred from the schema rather than widened to `unknown`.
- Derive the params type from the schema with `Static<typeof Params>` (`import type { Static } from "typebox"`); do not hand-write a parallel interface.
- Narrow `tool_call` inputs with `isToolCallEventType("bash", event)` instead of `event.input.command as string`.
- Type `details` with an interface and build it with `satisfies`, so renderers can read it back with a typed cast in one place.
- When reconstructing state from `getBranch()`, narrow entries with explicit checks (`entry.type === "message"`, `msg.role === "toolResult"`, `msg.toolName === "x"`), then validate `details` shape before use; old entries may predate your current shape.
- Import `import type` for type-only symbols; pi's own examples use `.ts` extensions in relative imports (`examples/extensions/plan-mode/index.ts`).
