# Lifecycle, events, and gating

Judgment that complements `docs/extensions.md` (sections "Respect the runtime lifecycle", "Events and concurrency", "Context and session changes", "Errors and cleanup"). Paths are relative to the installed pi package.

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
