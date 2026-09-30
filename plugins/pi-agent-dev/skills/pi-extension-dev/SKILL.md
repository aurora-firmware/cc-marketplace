---
name: pi-extension-dev
description: >-
  Expert guidance for building, modifying, debugging, and reviewing extensions
  for the pi coding agent (@earendil-works/pi-coding-agent): TypeScript modules
  that register tools, slash commands, event handlers, providers, and terminal
  UI through the ExtensionAPI. Locates the installed pi docs and examples so
  they match the running version, chooses the right integration point, applies
  the extension lifecycle, state, mode, and cleanup contracts, and starts from
  the closest official example. Use whenever the user mentions pi extensions,
  pi.registerTool, pi.registerCommand, pi.on, ExtensionAPI, pi packages,
  `pi --extension`, or asks how to add a tool, command, guard, status line,
  renderer, or provider to pi, even if they do not say "skill".
---

# Pi extension development

Pi extensions are TypeScript modules that run **inside the pi process** with its OS permissions. Do not guess the API: the installed docs and examples are the source of truth, and this skill tells you how to find and apply them.

## Step 0: Locate the docs and pin the version

Run the helper from this skill's base directory:

```bash
bash <base-directory>/scripts/locate-pi.sh
```

- **Exit 0** prints `PACKAGE`, `VERSION`, `DOCS`, `EXAMPLES`. Read docs from `DOCS` and examples from `EXAMPLES`; state the `VERSION` in your first message about the task. Every docs and examples path cited below is relative to `PACKAGE`.
- **Exit 1** (pi not installed, or only the old `@mariozechner/pi-coding-agent` name): tell the user, and use the upstream repo `https://github.com/earendil-works/pi/tree/main/packages/coding-agent` (`docs/`, `examples/`) as the source. Say which version you could not confirm.
- **Exit 2** (stripped install): same fallback; the version is still printed.

Optional freshness check after a pi upgrade: `bash <base-directory>/scripts/check-doc-paths.sh <base-directory>/SKILL.md <base-directory>/references/*.md` lists any path this skill cites that no longer exists. If it reports missing paths, list the real directory instead of trusting the citation.

## Step 1: Choose the integration point

Read `references/decisions.md` (section "Choosing the mechanism"). Extensions are for executable behavior. If instructions alone suffice, recommend a skill or prompt template instead. Embedding pi in another application (SDK, RPC, JSON mode) is **not covered by this plugin yet**: read `docs/sdk.md` and `docs/cli-integration.md` directly and say so.

| Capability | Main API |
|---|---|
| Observe or modify lifecycle behavior | `pi.on(event, handler)` |
| Model-callable operation | `pi.registerTool()` (use `defineTool()` for standalone definitions) |
| `/` command | `pi.registerCommand()` |
| Shortcut / CLI flag | `pi.registerShortcut()` / `pi.registerFlag()` |
| Send messages | `pi.sendUserMessage()` / `pi.sendMessage()` |
| Persist data outside model context | `pi.appendEntry()` |
| Change active tools, model, thinking level | `pi.setActiveTools()`, `pi.setModel()`, `pi.setThinkingLevel()` |
| Model provider | `pi.registerProvider()` |
| Rendering / UI | renderers plus `ctx.ui` |
| Extension-to-extension messaging | `pi.events` |

## Step 2: Apply the contracts

Read `docs/extensions.md` in full (it is short), then check your design against the contracts in `references/decisions.md`: lifecycle (no side effects in the factory), events and concurrency, tools, state placement, modes (`ctx.mode`, `ctx.hasUI`), errors and cleanup, packaging. When the docs and an example disagree, **the docs win**; `references/decisions.md` lists known cases.

## Step 3: Start from the closest example

Look up your task in `references/example-index.md`, then **read that example file before writing code**. Copy its structure, not its shortcuts.

## Step 4: Write it

- Default-export a factory `(pi: ExtensionAPI) => void | Promise<void>`. Imports come from `@earendil-works/pi-coding-agent`, `@earendil-works/pi-ai`, `@earendil-works/pi-tui`, and `typebox`; pi supplies these at runtime, so list them as `peerDependencies` (`"*"`) when packaging.
- Small extension: one `.ts` file. Multi-file: a directory with `index.ts`. Distributed: a pi package with a `pi.extensions` entry in `package.json` (`docs/packages.md`).
- Pi loads TypeScript through `jiti`: **there is no compile step and no type checking at load**. Run `tsc --noEmit` yourself; see the `typescript-best-practices` skill.

## Step 5: Verify

1. Typecheck (`tsc --noEmit`, with the pi packages and `typebox` installed as dev dependencies).
2. Load it: `pi --extension ./your-extension.ts`, then exercise the command, tool, or event.
3. Run `/reload` and confirm state, timers, and processes are cleaned up and rebuilt correctly.
4. Check behavior in non-interactive modes if the extension uses `ctx.ui` (`ctx.hasUI` is false in print/JSON mode).

## Where to read next

| Need | Doc (relative to `PACKAGE`) |
|---|---|
| Extension contracts | `docs/extensions.md` |
| How the agent loop, sessions, and context fit together | `docs/how-pi-works.md` |
| Custom components, overlays, themes in UI | `docs/tui.md` |
| Distribute or install extensions | `docs/packages.md` |
| Model providers | `docs/custom-provider.md` |
| RPC forwarding of dialogs | `docs/rpc-extension-ui.md` |
| Compaction | `docs/compaction.md` |
| Session entries and message shapes | `docs/session-format.md`, `docs/message-types.md` |
| Skills / prompt templates (not extensions) | `docs/skills.md`, `docs/prompt-templates.md` |
| Settings and discovery locations | `docs/configuration.md`, `docs/settings.md` |
| Security model | `docs/security.md` |
| Exact types | `dist/core/extensions/types.d.ts` |
