# Example index

Map a task to the closest official example. Paths are relative to the installed pi package (`EXAMPLES` from `locate-pi.sh`, one level up). Read the example before writing code, and read `references/decisions.md` for where examples cut corners. The full annotated list is `examples/extensions/README.md`.

## Start here

| Task | Example |
|---|---|
| Smallest possible extension with one tool | `examples/extensions/hello.ts` |
| Registering commands | `examples/extensions/commands.ts` |
| Extension with npm dependencies | `examples/extensions/with-deps/` |

## Tools

| Task | Example |
|---|---|
| Stateful tool with branch-aware state, renderers, and a `/command` UI | `examples/extensions/todo.ts` |
| Truncate large output correctly | `examples/extensions/truncated-tool.ts` |
| Register tools after startup or at runtime | `examples/extensions/dynamic-tools.ts` |
| Override or audit a built-in tool | `examples/extensions/tool-override.ts` |
| Custom rendering for built-in tools | `examples/extensions/built-in-tool-renderer.ts` |
| End the run on a tool result (`terminate: true`) | `examples/extensions/structured-output.ts` |
| Tools that must not run concurrently | `examples/extensions/tic-tac-toe.ts` |
| Delegate work to isolated sub-agents | `examples/extensions/subagent/` |
| Route tools to a remote machine or sandbox | `examples/extensions/ssh.ts`, `examples/extensions/sandbox/` |
| Ask the user questions from a tool | `examples/extensions/question.ts`, `examples/extensions/questionnaire.ts` |

## Gates and safety

| Task | Example |
|---|---|
| Confirm dangerous bash commands | `examples/extensions/permission-gate.ts` |
| Block writes to protected paths | `examples/extensions/protected-paths.ts` |
| Confirm destructive session actions | `examples/extensions/confirm-destructive.ts` |
| Guard session changes on a dirty repo | `examples/extensions/dirty-repo-guard.ts` |
| Project trust decisions | `examples/extensions/project-trust.ts` |

## Commands, modes, and workflow

| Task | Example |
|---|---|
| Read-only plan mode with tool switching and persisted state | `examples/extensions/plan-mode/` |
| Named presets for model, tools, and instructions | `examples/extensions/preset.ts` |
| Toggle tools interactively | `examples/extensions/tools.ts` |
| Hand context to a new session | `examples/extensions/handoff.ts` |
| Reload safely from a command and a tool | `examples/extensions/reload-runtime.ts` |
| Orderly shutdown command | `examples/extensions/shutdown-command.ts` |
| Send a user message from an extension | `examples/extensions/send-user-message.ts` |
| Transform user input | `examples/extensions/input-transform.ts`, `examples/extensions/inline-bash.ts` |

## Session, context, and prompt

| Task | Example |
|---|---|
| Modify the system prompt | `examples/extensions/pirate.ts`, `examples/extensions/prompt-customizer.ts` |
| Add rules or context from files | `examples/extensions/claude-rules.ts` |
| Custom compaction | `examples/extensions/custom-compaction.ts`, `examples/extensions/trigger-compact.ts` |
| Git checkpoints per turn | `examples/extensions/git-checkpoint.ts` |
| Name or bookmark sessions | `examples/extensions/session-name.ts`, `examples/extensions/bookmark.ts` |
| Load skills, prompts, themes dynamically | `examples/extensions/dynamic-resources/` |
| Talk to another extension | `examples/extensions/event-bus.ts` |
| Watch a file and inject content | `examples/extensions/file-trigger.ts` |

## Terminal UI

| Task | Example |
|---|---|
| Status line text | `examples/extensions/status-line.ts` |
| Widgets above or below the editor | `examples/extensions/widget-placement.ts` |
| Custom footer or header | `examples/extensions/custom-footer.ts`, `examples/extensions/custom-header.ts` |
| Custom editor | `examples/extensions/modal-editor.ts` |
| Overlays | `examples/extensions/overlay-qa-tests.ts` |
| Custom message or entry rendering | `examples/extensions/message-renderer.ts`, `examples/extensions/entry-renderer.ts` |
| Dialogs that auto-dismiss on a signal | `examples/extensions/timed-confirm.ts` |
| RPC-compatible extension UI | `examples/extensions/rpc-demo.ts` |

## Providers

| Task | Example |
|---|---|
| Custom model provider with OAuth and streaming | `examples/extensions/custom-provider-anthropic/` |
| Provider reusing built-in streaming through a proxy | `examples/extensions/custom-provider-gitlab-duo/` |
