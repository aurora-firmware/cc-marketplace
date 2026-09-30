# Choosing the mechanism and packaging

Paths are relative to the installed pi package.

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

## Packaging

- One file for small; a directory with `index.ts` for multi-file; a pi package for distribution or dependencies (`docs/packages.md`).
- List pi's own packages (`@earendil-works/pi-ai`, `pi-agent-core`, `pi-coding-agent`, `pi-tui`) and `typebox` under `peerDependencies` with `"*"`; do not bundle them. Other runtime imports go in `dependencies` (`examples/extensions/with-deps/`).
- Installed packages have separate module roots: do not rely on two packages sharing a dependency instance.
- Declare resources under the `pi` key in `package.json` (`extensions`, `skills`, `prompts`, `themes`) or use conventional directories. The `pi-package` keyword makes an npm package discoverable.
