# Pitfalls when copying from pi's examples

The examples are a teaching aid, not a contract. When they disagree with `docs/`, the docs win. Known cases at pi 0.87.1; re-check when the version changes. Paths are relative to the installed pi package.

## Examples that deviate from the docs

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
