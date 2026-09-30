# State, modes, and UI

Judgment that complements `docs/extensions.md` (sections "State" and "UI and modes") and `docs/tui.md`. Paths are relative to the installed pi package.

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
