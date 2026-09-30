# Pi extension design decisions

Curated judgment for building pi extensions. It complements `docs/extensions.md` (read it first) and does not restate it. Paths are relative to the installed pi package.

## Choosing the mechanism

Use the smallest mechanism that meets the need (`docs/quickstart.md`, "choose how to customize pi").

| Need | Use | Why |
|---|---|---|
| Reusable instructions or workflow the model should follow | Skill (`docs/skills.md`) | Loaded on demand, no code, cheap in context |
| Reusable message text the user triggers | Prompt template (`docs/prompt-templates.md`) | Expands editor input, no runtime |
| Colors | Theme (`docs/themes.md`) | Data only |
| Tools, commands, gates, event reactions, providers, UI | Extension (`docs/extensions.md`) | Only extensions run code in the pi process |
| Share any of the above | Pi package (`docs/packages.md`) | npm/git distribution with dependencies |
| Use pi from your own program | SDK, RPC, or JSON mode (`docs/sdk.md`, `docs/cli-integration.md`) | Different job; not an extension |

Rule of thumb: if the behavior can be expressed as instructions, do not write an extension. Extensions run with the process's OS permissions and can read prompts, files, credentials, and history (`docs/security.md`); every line of executable code is trust surface.

## Lifecycle

- The factory may be async, and pi waits for it. Use that only for startup configuration or provider registration.
- **No side effects in the factory.** Some invocations load extensions without starting a session. Start processes, sockets, watchers, and timers from `session_start` or from the command or tool that needs them.
- Close them in an **idempotent** `session_shutdown` handler; cancellation, reload, session replacement, and exit can all reach the same cleanup.
- Reload replaces the runtime. Never touch pre-reload state after `await ctx.reload()`; treat reload as terminal for the handler.
- Session replacement (`newSession`, `fork`, switch) invalidates the old context. Capture plain data first; use the fresh context passed to `withSession` for session-bound work.
- `ctx.reload()`, `waitForIdle()`, `newSession()`, and tree navigation exist only on `ExtensionCommandContext` (command handlers). Calling them from lifecycle handlers can deadlock. A tool cannot reload directly: queue a command with `pi.sendUserMessage("/your-command", { deliverAs: "followUp" })` (pattern: `examples/extensions/reload-runtime.ts`).
- For end-of-run work use `agent_before_settle` (last actionable point, can request one continuation) or `agent_settled` (final, notification only). `agent_end` can still be followed by retries or queued work.

## Events and gating

- Handlers run in load order. `pi.on()` returns an unsubscribe function.
- Return the event's declared result type only; returning something else has no effect. Return `undefined` to pass through.
- **Gates fail safe.** A `tool_call` handler that throws blocks the tool. When a gate needs the user but `ctx.hasUI` is false, block by default (pattern: `examples/extensions/permission-gate.ts`).
- Tool calls from one assistant message can run in parallel: never assume a sibling call or result exists.
- Use `ctx.signal` for nested work owned by an active turn; commands and idle events often have no signal.
- Continuation from `turn_end` or `agent_before_settle` can loop: guard every `continue: true` with a condition that ends.
- Prefer changing prompt sections, selected tools, or guidelines in `before_agent_start` over returning a full `systemPrompt`, which replaces the whole prompt for the run.
- `context` transforms messages; use `context_with_system` only when a request-local transformation must own the full transcript.

## Tools

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

## State

Pick storage by how the state should behave with the conversation tree (`docs/extensions.md`):

| State | Storage |
|---|---|
| Follows the active branch (forks, rewinds) | Tool-result `details` |
| Durable, excluded from model context | `pi.appendEntry()` |
| Custom content stored and sent to the model | `pi.sendMessage()` |
| Outside one session | External storage |

Rebuild branch-sensitive state on `session_start` **and** `session_tree` by walking `ctx.sessionManager.getBranch()`, not every file entry: abandoned branches are alternative histories (`examples/extensions/todo.ts`). Register an entry or message renderer if stored content should show in the transcript.

## Modes and UI

- Extensions load in interactive, RPC, JSON, and print modes. Keep tool and event behavior independent of rendering.
- `ctx.mode === "tui"` guards terminal-only UI (custom components). `ctx.hasUI` covers dialogs available in TUI and RPC.
- Prefer built-in `ctx.ui` (`select`, `confirm`, `input`, `notify`, `setStatus`, `setWidget`) over `ctx.ui.custom()`. Use custom components only when the interaction needs its own rendering and input.
- Custom components: every line must fit the given width (`visibleWidth`, `truncateToWidth`, `wrapTextWithAnsi`), cache by width and invalidate on state or theme change, use the injected theme and keybindings, and finish through the completion callback (`docs/tui.md`).
- Give each `setStatus`/`setWidget` a stable key and clear it (`undefined`) when the feature turns off (`examples/extensions/plan-mode/index.ts`).

## Typing patterns

- Use `defineTool({...})` for tools assigned to a variable or array, so parameter types are inferred from the schema rather than widened to `unknown`.
- Derive the params type from the schema with `Static<typeof Params>` (`import type { Static } from "typebox"`); do not hand-write a parallel interface.
- Narrow `tool_call` inputs with `isToolCallEventType("bash", event)` instead of `event.input.command as string`.
- Type `details` with an interface and build it with `satisfies`, so renderers can read it back with a typed cast in one place.
- When reconstructing state from `getBranch()`, narrow entries with explicit checks (`entry.type === "message"`, `msg.role === "toolResult"`, `msg.toolName === "x"`), then validate `details` shape before use; old entries may predate your current shape.
- Import `import type` for type-only symbols; pi's own examples use `.ts` extensions in relative imports (`examples/extensions/plan-mode/index.ts`).

## Packaging

- One file for small; a directory with `index.ts` for multi-file; a pi package for distribution or dependencies (`docs/packages.md`).
- List pi's own packages (`@earendil-works/pi-ai`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`) and `typebox` under `peerDependencies` with `"*"`; do not bundle them. Other runtime imports go in `dependencies` (`examples/extensions/with-deps/`).
- Installed packages have separate module roots: do not rely on two packages sharing a dependency instance.
- Declare resources under the `pi` key in `package.json` (`extensions`, `skills`, `prompts`, `themes`) or use conventional directories. The `pi-package` keyword makes an npm package discoverable.

## Examples that deviate from the docs

The examples are a teaching aid, not a contract. When they disagree with `docs/`, the docs win. Known cases at pi 0.87.1; re-check when the version changes.

- `examples/extensions/event-bus.ts` stores the `ctx` from `session_start` and uses it later inside an event callback. It does refresh the stored `ctx` on every `session_start`, so the risk is narrower: the docs say session replacement and reload invalidate old contexts, and the stored one can be stale between a reload or session replacement and the next `session_start`, which is a window in which the `pi.events` callback can still run. Use the context passed to each handler instead of a stored one.
- `examples/extensions/todo.ts` returns `Error: ...` text with `details.error` for bad input instead of throwing. Per `docs/extensions.md`, that is a successful result as far as the model and session are concerned. Throw to signal failure.
- Examples often cast tool inputs (`event.input.command as string`). Prefer `isToolCallEventType`.

## Anti-patterns

- Starting timers, watchers, or child processes in the factory.
- Holding a `ctx` across a reload or session replacement.
- Rebuilding state from all session entries instead of the active branch.
- Unbounded tool output.
- An unconditional `continue: true`.
- A gate that allows the action when there is no UI to ask.
- Writing an extension when a skill or prompt template would do.
