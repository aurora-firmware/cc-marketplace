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

## Five things that are easy to get wrong

1. **Import from `@earendil-works/pi-coding-agent`** (and `@earendil-works/pi-ai`, `@earendil-works/pi-tui`, `typebox`). The older `@mariozechner/pi-coding-agent` name is retired, yet it is what models reach for from memory.
2. **State the pi version** you read the docs from (Step 0) in your first message about the task, so the user can see the guidance matches their install.
3. **Tools signal failure by throwing.** Returning text that says "Error" is still a successful result.
4. **Pi loads TypeScript through `jiti`, with no type checking.** Run `tsc --noEmit` yourself, and tell the user to load the extension with `pi --extension ./file.ts`.
5. **Embedding pi in another app (SDK, RPC, JSON mode) is not covered by this plugin yet.** Say so, then answer from `docs/sdk.md` and `docs/cli-integration.md`.

## Step 0: Locate the docs and pin the version

Run the helper from this skill's base directory:

```bash
bash <base-directory>/scripts/locate-pi.sh
```

It searches, in order: `$PI_PACKAGE_DIR` (env override for non-standard installs), `$PWD/node_modules`, the package that contains the running `pi` binary (resolved through symlinks, so installs from pi's own installer, pnpm, bun or volta are found), then the global npm root.

- **Exit 0** prints `PACKAGE`, `VERSION`, `DOCS`, `EXAMPLES`. Read docs from `DOCS` and examples from `EXAMPLES`; state the `VERSION` in your first message about the task. Every docs and examples path cited below is relative to `PACKAGE`. A `warning: project-local pi X differs from the running pi Y` on stderr means the running pi is not the project's dev dependency: when authoring for the user's installed pi, prefer the running pi's docs by re-running with `PI_PACKAGE_DIR=<the running pi's dir>`.
- **Exit 1** (not found, or only the old `@mariozechner/pi-coding-agent` name): run `pi --version`.
  - If it works, pi is installed by a method the locator could not resolve. Tell the user, record that version, ask for (or derive) the install dir, and re-run with `PI_PACKAGE_DIR=<dir>`.
  - Only if that also fails, or pi is truly absent, tell the user and use the upstream repo as the source (`docs/`, `examples/`): prefer the release tag for the known version if such a tag exists (try `https://github.com/earendil-works/pi/tree/v<version>/packages/coding-agent`), otherwise `https://github.com/earendil-works/pi/tree/main/packages/coding-agent`. Say which you used and which version you could not confirm.
- **Exit 2** (stripped install): same upstream fallback, preferring the tag for the printed `VERSION` if such a tag exists, else `main`; say which you used.

Optional freshness check after a pi upgrade: `bash <base-directory>/scripts/check-doc-paths.sh <base-directory>/SKILL.md <base-directory>/references/*.md` lists any path this skill cites that no longer exists. If it reports missing paths, list the real directory instead of trusting the citation.

## Step 1: Choose the integration point

Extensions are for executable behavior. If instructions alone suffice, recommend a skill or prompt template instead (`references/mechanism.md` has the decision table).

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

Read only what your task needs. Each reference is short and complements the matching section of `docs/extensions.md`; read that section too when you are unsure of a contract (list the headings with `grep -n '^##' <DOCS>/extensions.md`, then read the section).

| You are building | Read |
|---|---|
| A tool the model calls | `references/tools.md` |
| A gate, event handler, or anything with startup or cleanup | `references/lifecycle-events.md` |
| State that must survive fork, rewind, or reload | `references/state-ui.md` (State) |
| Status line, widget, dialog, custom component, or mode-aware behavior | `references/state-ui.md` (Modes and UI), plus `docs/tui.md` for custom components |
| Something to share or install | `references/mechanism.md` (Packaging), `docs/packages.md` |
| A decision between extension, skill, prompt template, or SDK | `references/mechanism.md` |
| Type questions for tools, events, or state | `references/typing.md` |

When the docs and an example disagree, **the docs win**; `references/pitfalls.md` lists known cases and is worth a glance before you copy from an example.

## Step 3: Start from the closest example

Pick the closest entry in pi's own annotated map, `examples/extensions/README.md` (grouped by Lifecycle & Safety, Custom Tools, Commands & UI, System Prompt & Compaction, Messages, Providers, and so on), and **read that example file before writing code**. Copy its structure, not its shortcuts.

## Step 4: Write it

- Default-export a factory `(pi: ExtensionAPI) => void | Promise<void>`. Imports come from `@earendil-works/pi-coding-agent`, `@earendil-works/pi-ai`, `@earendil-works/pi-tui`, and `typebox`; pi supplies these at runtime, so list them as `peerDependencies` (`"*"`) when packaging.
- Small extension: one `.ts` file. Multi-file: a directory with `index.ts`. Distributed: a pi package with a `pi.extensions` entry in `package.json` (`docs/packages.md`).
- For TypeScript conventions and `tsconfig` choices, see the `typescript-best-practices` skill.

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
