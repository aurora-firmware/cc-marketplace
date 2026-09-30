# pi-agent-dev

`pi-agent-dev` is a Claude Code plugin that turns a session into an expert at building extensions for the [pi coding agent](https://github.com/earendil-works/pi) (`@earendil-works/pi-coding-agent`).

## Skills

- `/pi-agent-dev:pi-extension-dev` — locate the installed pi docs and examples, choose the integration point, apply the extension contracts (lifecycle, events, tools, state, UI and modes, cleanup), and start from the closest official example.
- `/pi-agent-dev:typescript-best-practices` — language practices and coding guidelines for TypeScript, including the constraints of extensions loaded through `jiti` (no type checking at load).

## How the docs are found

Nothing from pi's documentation is copied into this plugin. `pi-extension-dev` resolves the installed package's `docs/` and `examples/` at runtime, so the session always reads docs that match the pi version in use. Search order: `$PI_PACKAGE_DIR` (override for non-standard installs), the project's `node_modules`, the package containing the running `pi` binary (found by resolving it and walking up, which covers pi's own installer, pnpm, bun and volta), then the global npm root. If none is found, it falls back to the upstream repository, preferring the release tag for the installed version when it is known.

## Requirements

- pi installed as `@earendil-works/pi-coding-agent` (Node `>=22.19.0`). The older `@mariozechner/pi-coding-agent` package name is not supported.

## Deferred

A `pi-sdk-embedding` skill (embedding pi in another app through the SDK, RPC or JSON modes) is not built yet. `pi-extension-dev` points at `docs/sdk.md` in the meantime.

## Local test

```bash
claude --plugin-dir ./plugins/pi-agent-dev
```
