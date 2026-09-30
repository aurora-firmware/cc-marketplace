# pi-agent-dev Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `pi-agent-dev` plugin to this marketplace whose skills make a Claude Code session an expert at building extensions for the pi coding agent (`@earendil-works/pi-coding-agent`), with sound TypeScript practice.

**Architecture:** Two markdown-driven skills plus two small bash helpers. `pi-extension-dev` holds a short procedural `SKILL.md`, curated architecture judgment (`references/decisions.md`) and a task→example map (`references/example-index.md`). It never copies pi's docs: `scripts/locate-pi.sh` resolves the installed package's `docs/` and `examples/` at runtime, and `scripts/check-doc-paths.sh` verifies every `docs/…`/`examples/…` path the skill cites still exists in the installed version (freshness check). `typescript-best-practices` is independent of pi: `SKILL.md` plus `references/language.md` and `references/guidelines.md`.

**Tech Stack:** Markdown (skills), bash (helpers and their tests), JSON (manifests, eval fixtures), the installed pi package as the documentation source.

**Spec:** `docs/superpowers/specs/2026-09-30-pi-agent-dev-design.md`

## Global Constraints

- Canonical package is `@earendil-works/pi-coding-agent`. `@mariozechner/pi-coding-agent` is the old name and must never be used as a docs source or in code samples.
- Do not copy pi's `docs/` or `examples/` into the plugin; only cite paths inside the installed package.
- `pi-sdk-embedding` is deferred: do not create it. `pi-extension-dev` tells the session the SDK skill is not available and points at `docs/sdk.md`.
- Skills follow this repo's conventions (see `plugins/github-utils/skills/*`): `SKILL.md` with `name`/`description` front-matter, `references/` for conditionally-read material, `scripts/` for helpers, `evals/evals.json` entries shaped `{id, name, prompt, expected_output, files}`.
- `SKILL.md` files stay short (target under 150 lines); depth goes in `references/`.
- Plugin and marketplace versions are both `1.0.0` and must match. Marketplace entry uses `"category": "Developer Tools"`.
- Do not hardcode a published pi docs-site URL (none verified). The only fallback URL is `https://github.com/earendil-works/pi/tree/main/packages/coding-agent`.
- Node requirement for pi is `>=22.19.0` (from pi's `package.json` `engines`); state it where relevant, do not lower it.
- Work on branch `feat/pi-agent-dev` in `~/projects/cc-marketplace`, never on `main`. Commit messages use Conventional Commits (matching this repo's history: `feat(...)`, `docs(...)`, `chore:`) and end with the session's `Co-Authored-By` trailer.
- This repo has no CI. Verification is: bash test scripts pass, JSON parses, `check-doc-paths.sh` passes against the installed pi, and the plugin loads with `claude --plugin-dir`.

## Review Focus

- **Only the old `@mariozechner/pi-coding-agent` is installed:** `locate-pi.sh` must report "not found" (exit 1), not silently use it. Pinned by Task 2's old-name test.
- **pi not installed at all:** the session must get a clear message with the GitHub fallback, and `SKILL.md` must tell it how to proceed from that. Pinned by Task 2's not-found test and Task 7's eval 3.
- **Package path contains spaces:** `locate-pi.sh` and `check-doc-paths.sh` must quote paths. Pinned by Task 2's and Task 5's space-in-path fixtures.
- **pi upgrade moves or renames a doc/example:** `check-doc-paths.sh` must fail and name every missing path rather than pass silently. Pinned by Task 5's missing-path test.
- **Package found but `docs/` or `examples/` absent (stripped install):** exit 2 with the fallback URL, not a crash. Pinned by Task 2's no-docs test.

---

### Task 1: Plugin scaffold and marketplace entry

**Files:**
- Create: `plugins/pi-agent-dev/.claude-plugin/plugin.json`
- Create: `plugins/pi-agent-dev/README.md`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `README.md`

**Interfaces:**
- Produces: plugin directory `plugins/pi-agent-dev/` that later tasks add `skills/` under; plugin name `pi-agent-dev`, version `1.0.0`.

- [ ] **Step 1: Create the feature branch**

```bash
cd ~/projects/cc-marketplace
git switch -c feat/pi-agent-dev
```

Expected: `Switched to a new branch 'feat/pi-agent-dev'`

- [ ] **Step 2: Write the plugin manifest**

Create `plugins/pi-agent-dev/.claude-plugin/plugin.json`:

```json
{
  "name": "pi-agent-dev",
  "description": "Expert guidance for building extensions for the pi coding agent: locates the installed pi docs and examples, chooses the right integration point, applies the extension contracts, plus TypeScript best practices.",
  "version": "1.0.0",
  "author": {
    "name": "cc-marketplace maintainers"
  },
  "keywords": [
    "pi",
    "pi-agent",
    "pi-coding-agent",
    "extensions",
    "typescript"
  ],
  "homepage": "https://code.claude.com/docs/en/plugins",
  "license": "MIT"
}
```

- [ ] **Step 3: Add the marketplace entry**

In `.claude-plugin/marketplace.json`, append this object to the `plugins` array (after the `github-utils` entry, adding a comma after its closing brace):

```json
    {
      "name": "pi-agent-dev",
      "displayName": "Pi Agent Dev",
      "source": "./plugins/pi-agent-dev",
      "description": "Skills for building extensions for the pi coding agent (@earendil-works/pi-coding-agent) and writing sound TypeScript: docs located from the installed package, integration-point decisions, extension contracts, and a TypeScript practices guide.",
      "version": "1.0.0",
      "author": {
        "name": "cc-marketplace maintainers"
      },
      "keywords": [
        "pi",
        "pi-agent",
        "pi-coding-agent",
        "extensions",
        "typescript"
      ],
      "category": "Developer Tools"
    }
```

- [ ] **Step 4: Write the plugin README**

Create `plugins/pi-agent-dev/README.md`:

````markdown
# pi-agent-dev

`pi-agent-dev` is a Claude Code plugin that turns a session into an expert at building extensions for the [pi coding agent](https://github.com/earendil-works/pi) (`@earendil-works/pi-coding-agent`).

## Skills

- `/pi-agent-dev:pi-extension-dev` — locate the installed pi docs and examples, choose the integration point, apply the extension contracts (lifecycle, events, tools, state, UI and modes, cleanup), and start from the closest official example.
- `/pi-agent-dev:typescript-best-practices` — language practices and coding guidelines for TypeScript, including the constraints of extensions loaded through `jiti` (no type checking at load).

## How the docs are found

Nothing from pi's documentation is copied into this plugin. `pi-extension-dev` resolves the installed package's `docs/` and `examples/` at runtime (project `node_modules`, then the global npm root), so the session always reads docs that match the pi version in use. If pi is not installed, it falls back to the upstream repository.

## Requirements

- pi installed as `@earendil-works/pi-coding-agent` (Node `>=22.19.0`). The older `@mariozechner/pi-coding-agent` package name is not supported.

## Deferred

A `pi-sdk-embedding` skill (embedding pi in another app through the SDK, RPC or JSON modes) is not built yet. `pi-extension-dev` points at `docs/sdk.md` in the meantime.

## Local test

```bash
claude --plugin-dir ./plugins/pi-agent-dev
```
````

- [ ] **Step 5: Update the root README**

In `README.md`: change the opening line to `A Claude Code plugin marketplace with the `github-utils` and `pi-agent-dev` plugins.`; in the Structure list add `- `plugins/pi-agent-dev/.claude-plugin/plugin.json`` and `- `plugins/pi-agent-dev/skills/``; and after the `github-utils` section append:

````markdown
## Included plugin: pi-agent-dev

`pi-agent-dev` bundles skills for building pi coding agent extensions (`pi-extension-dev`) and writing sound TypeScript (`typescript-best-practices`). Test it with:

```bash
claude --plugin-dir ./plugins/pi-agent-dev
```
````

- [ ] **Step 6: Verify manifests**

```bash
cd ~/projects/cc-marketplace
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo marketplace-ok
python3 -m json.tool plugins/pi-agent-dev/.claude-plugin/plugin.json > /dev/null && echo plugin-ok
python3 - <<'PY'
import json
m = json.load(open(".claude-plugin/marketplace.json"))
p = json.load(open("plugins/pi-agent-dev/.claude-plugin/plugin.json"))
e = next(x for x in m["plugins"] if x["name"] == "pi-agent-dev")
assert e["version"] == p["version"] == "1.0.0", (e["version"], p["version"])
assert e["source"] == "./plugins/pi-agent-dev"
print("versions-match")
PY
```

Expected: `marketplace-ok`, `plugin-ok`, `versions-match`.

- [ ] **Step 7: Commit**

```bash
git add .claude-plugin/marketplace.json plugins/pi-agent-dev README.md
git commit -m "feat(pi-agent-dev): scaffold plugin and marketplace entry"
```

---

### Task 2: `locate-pi.sh` (TDD)

Resolves the installed pi package so skills read version-matched docs.

**Files:**
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/test-locate-pi.sh`
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/locate-pi.sh`

**Interfaces:**
- Produces: `locate-pi.sh` — no args; env `PI_PACKAGE_DIR` overrides the search. Search order: `$PI_PACKAGE_DIR`, `$PWD/node_modules/@earendil-works/pi-coding-agent`, `$(npm root -g)/@earendil-works/pi-coding-agent`. A candidate counts only if its `package.json` has `"name": "@earendil-works/pi-coding-agent"`.
  - Exit 0: stdout `PACKAGE=<dir>`, `VERSION=<x.y.z>`, `DOCS=<dir>/docs`, `EXAMPLES=<dir>/examples`.
  - Exit 1: not found; stderr message contains `not found` and the fallback URL.
  - Exit 2: package found but `docs/` or `examples/` missing; stdout has `PACKAGE=` and `VERSION=`; stderr has the fallback URL.
- Produces: `test-locate-pi.sh` — runs the four cases, exits non-zero on any failure. Reused by Task 5's test as a pattern.

- [ ] **Step 1: Write the failing test**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/test-locate-pi.sh`:

```bash
#!/usr/bin/env bash
# Tests for locate-pi.sh. Run: bash test-locate-pi.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/locate-pi.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cwd" "$tmp/bin"
failures=0

assert() { # name, status (0 = pass)
  if [ "$2" -eq 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

make_pkg() { # dir, package-name, with-docs (yes|no)
  mkdir -p "$1"
  printf '{\n\t"name": "%s",\n\t"version": "1.2.3"\n}\n' "$2" > "$1/package.json"
  if [ "$3" = "yes" ]; then mkdir -p "$1/docs" "$1/examples"; fi
}

# Minimal PATH with no npm, so only PI_PACKAGE_DIR and $PWD/node_modules are searched.
for tool in sed head grep; do ln -s "$(command -v "$tool")" "$tmp/bin/$tool"; done
run() { (cd "$tmp/cwd" && env -i PATH="$tmp/bin" "$@" "$BASH" "$script"); }

# 1. Found with docs and examples (path contains a space).
make_pkg "$tmp/ok pkg" "@earendil-works/pi-coding-agent" yes
out="$(run PI_PACKAGE_DIR="$tmp/ok pkg" 2>"$tmp/err")"; rc=$?
assert "found: exit 0" "$rc"
[[ "$out" == *"VERSION=1.2.3"* ]]; assert "found: prints version" $?
[[ "$out" == *"DOCS=$tmp/ok pkg/docs"* ]]; assert "found: prints docs dir with space intact" $?
[[ "$out" == *"EXAMPLES=$tmp/ok pkg/examples"* ]]; assert "found: prints examples dir" $?

# 2. Not found anywhere.
out="$(run PI_PACKAGE_DIR="$tmp/missing" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 1 ]; assert "not found: exit 1" $?
grep -q "not found" "$tmp/err"; assert "not found: stderr says not found" $?
grep -q "github.com/earendil-works/pi" "$tmp/err"; assert "not found: stderr gives fallback URL" $?

# 3. Package present but docs/examples stripped.
make_pkg "$tmp/nodocs" "@earendil-works/pi-coding-agent" no
out="$(run PI_PACKAGE_DIR="$tmp/nodocs" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 2 ]; assert "no docs: exit 2" $?
[[ "$out" == *"PACKAGE=$tmp/nodocs"* ]]; assert "no docs: still prints package" $?
grep -q "github.com/earendil-works/pi" "$tmp/err"; assert "no docs: stderr gives fallback URL" $?

# 4. Old package name is not accepted.
make_pkg "$tmp/old" "@mariozechner/pi-coding-agent" yes
out="$(run PI_PACKAGE_DIR="$tmp/old" 2>"$tmp/err")"; rc=$?
[ "$rc" -eq 1 ]; assert "old name: rejected with exit 1" $?

[ "$failures" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev/scripts
bash test-locate-pi.sh
```

Expected: FAIL lines (the script `locate-pi.sh` does not exist yet, so `bash` errors and every case fails); final exit status non-zero.

- [ ] **Step 3: Write the implementation**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/locate-pi.sh`:

```bash
#!/usr/bin/env bash
# Locate the installed pi coding-agent package and its docs/examples.
# Prints KEY=value lines. Exit 0: found with docs+examples.
# Exit 1: not found. Exit 2: found but docs/ or examples/ missing.
set -euo pipefail

PKG_NAME="@earendil-works/pi-coding-agent"
FALLBACK_URL="https://github.com/earendil-works/pi/tree/main/packages/coding-agent"

candidates=()
if [ -n "${PI_PACKAGE_DIR:-}" ]; then
  candidates+=("$PI_PACKAGE_DIR")
fi
candidates+=("$PWD/node_modules/$PKG_NAME")
if command -v npm >/dev/null 2>&1; then
  global_root="$(npm root -g 2>/dev/null || true)"
  if [ -n "$global_root" ]; then
    candidates+=("$global_root/$PKG_NAME")
  fi
fi

for dir in "${candidates[@]}"; do
  [ -f "$dir/package.json" ] || continue
  grep -q "\"name\": *\"$PKG_NAME\"" "$dir/package.json" || continue
  version="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$dir/package.json" | head -n 1)"
  echo "PACKAGE=$dir"
  echo "VERSION=$version"
  if [ -d "$dir/docs" ] && [ -d "$dir/examples" ]; then
    echo "DOCS=$dir/docs"
    echo "EXAMPLES=$dir/examples"
    exit 0
  fi
  echo "warning: $dir has no docs/ or examples/; use the upstream fallback: $FALLBACK_URL" >&2
  exit 2
done

echo "pi package $PKG_NAME not found (searched: ${candidates[*]}). The older @mariozechner/pi-coding-agent name is not supported. Fall back to $FALLBACK_URL" >&2
exit 1
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
bash test-locate-pi.sh
```

Expected: every line `ok   - …`, exit status 0.

- [ ] **Step 5: Run it against the real install**

```bash
chmod +x locate-pi.sh test-locate-pi.sh
./locate-pi.sh
```

Expected (at time of writing): `PACKAGE=…/@earendil-works/pi-coding-agent`, `VERSION=0.87.1` (or newer), `DOCS=…/docs`, `EXAMPLES=…/examples`, exit 0.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev/skills/pi-extension-dev/scripts
git commit -m "feat(pi-agent-dev): add locate-pi.sh to resolve the installed pi docs"
```

---

### Task 3: `pi-extension-dev` SKILL.md

**Files:**
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/SKILL.md`

**Interfaces:**
- Consumes: `scripts/locate-pi.sh` output keys and exit codes (Task 2); `references/decisions.md` (Task 4) and `references/example-index.md` (Task 5) by relative path.
- Produces: the skill entrypoint; its cited `docs/…`/`examples/…` paths are validated by `check-doc-paths.sh` in Task 5.

- [ ] **Step 1: Write `SKILL.md`**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/SKILL.md`:

````markdown
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
````

- [ ] **Step 2: Structural check**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev
head -3 SKILL.md | grep -q '^name: pi-extension-dev$' && echo name-ok
wc -l SKILL.md
```

Expected: `name-ok`, and a line count under 150.

- [ ] **Step 3: Commit**

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev/skills/pi-extension-dev/SKILL.md
git commit -m "feat(pi-agent-dev): add pi-extension-dev skill entrypoint"
```

---

### Task 4: `references/decisions.md`

The curated architecture judgment. It points at docs rather than restating them, and it records where examples deviate from the docs.

**Files:**
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/references/decisions.md`

**Interfaces:**
- Consumes: nothing.
- Produces: sections named "Choosing the mechanism", "Lifecycle", "Events and gating", "Tools", "State", "Modes and UI", "Typing patterns", "Packaging", "Examples that deviate from the docs" (SKILL.md refers to the first by name).

- [ ] **Step 1: Write `decisions.md`**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/references/decisions.md`:

````markdown
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

- `examples/extensions/event-bus.ts` stores the `ctx` from `session_start` and uses it later inside an event callback. The docs say session replacement and reload invalidate old contexts. Use the context passed to each handler instead, or refresh the stored one on every `session_start`.
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
````

- [ ] **Step 2: Structural check**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev
for h in "## Choosing the mechanism" "## Lifecycle" "## Events and gating" "## Tools" "## State" "## Modes and UI" "## Typing patterns" "## Packaging" "## Examples that deviate from the docs"; do
  grep -qxF "$h" references/decisions.md && echo "ok $h" || echo "MISSING $h"
done
```

Expected: nine `ok` lines, no `MISSING`.

- [ ] **Step 3: Commit**

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev/skills/pi-extension-dev/references/decisions.md
git commit -m "docs(pi-agent-dev): add curated pi extension design decisions"
```

---

### Task 5: `check-doc-paths.sh` (TDD) and `example-index.md`

**Files:**
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/test-check-doc-paths.sh`
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/check-doc-paths.sh`
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/references/example-index.md`

**Interfaces:**
- Consumes: `locate-pi.sh` (Task 2), including `PI_PACKAGE_DIR`.
- Produces: `check-doc-paths.sh <file.md>...` — for each backticked path starting with `docs/` or `examples/` (anchor after `#` ignored) in each file, checks it exists under `PACKAGE`. Exit 0 all present (stdout `all cited docs/examples paths exist in <dir>`); exit 1 if any missing (stdout `MISSING: <path> (cited in <file>)` per path); exit 64 on no arguments; propagates `locate-pi.sh`'s non-zero exit if pi is not found.

- [ ] **Step 1: Write the failing test**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/test-check-doc-paths.sh`:

```bash
#!/usr/bin/env bash
# Tests for check-doc-paths.sh. Run: bash test-check-doc-paths.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/check-doc-paths.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

assert() { # name, status (0 = pass)
  if [ "$2" -eq 0 ]; then echo "ok   - $1"; else echo "FAIL - $1"; failures=$((failures + 1)); fi
}

pkg="$tmp/pkg with space"
mkdir -p "$pkg/docs" "$pkg/examples/extensions/some-dir"
printf '{"name": "@earendil-works/pi-coding-agent", "version": "1.2.3"}\n' > "$pkg/package.json"
touch "$pkg/docs/a.md" "$pkg/examples/extensions/a.ts"
export PI_PACKAGE_DIR="$pkg"

# 1. Every cited path exists (file, directory, and #anchor forms).
cat > "$tmp/good.md" <<'MD'
See `docs/a.md#section`, `examples/extensions/a.ts` and `examples/extensions/some-dir/`.
Not checked: `references/decisions.md` and plain docs/missing.md without backticks.
MD
out="$(bash "$script" "$tmp/good.md" 2>&1)"; rc=$?
assert "all present: exit 0" "$rc"
[[ "$out" == *"all cited docs/examples paths exist"* ]]; assert "all present: success message" $?

# 2. A missing path is reported and fails.
cat > "$tmp/bad.md" <<'MD'
See `docs/a.md` and `examples/extensions/gone.ts` and `docs/also-gone.md`.
MD
out="$(bash "$script" "$tmp/bad.md" 2>/dev/null)"; rc=$?
[ "$rc" -eq 1 ]; assert "missing: exit 1" $?
[[ "$out" == *"MISSING: examples/extensions/gone.ts"* ]]; assert "missing: names first path" $?
[[ "$out" == *"MISSING: docs/also-gone.md"* ]]; assert "missing: names second path" $?
[[ "$out" != *"MISSING: docs/a.md"* ]]; assert "missing: does not flag existing path" $?

# 3. Multiple files are all checked.
out="$(bash "$script" "$tmp/good.md" "$tmp/bad.md" 2>/dev/null)"; rc=$?
[ "$rc" -eq 1 ]; assert "multi-file: fails if any file has a missing path" $?

# 4. No arguments is a usage error.
bash "$script" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 64 ]; assert "no args: exit 64" $?

[ "$failures" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev/scripts
bash test-check-doc-paths.sh
```

Expected: FAIL lines (script does not exist yet); non-zero exit.

- [ ] **Step 3: Write the implementation**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/scripts/check-doc-paths.sh`:

```bash
#!/usr/bin/env bash
# Verify that docs/ and examples/ paths cited in markdown files exist in the installed pi package.
# Usage: check-doc-paths.sh <file.md>...   (package resolved by locate-pi.sh; honours PI_PACKAGE_DIR)
# Exit 0: all present. Exit 1: some missing. Exit 64: usage. Other: locate-pi.sh failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <file.md>..." >&2
  exit 64
fi

info="$(bash "$here/locate-pi.sh")"
pkg="$(printf '%s\n' "$info" | sed -n 's/^PACKAGE=//p')"

missing=0
for file in "$@"; do
  while IFS= read -r cited; do
    if [ ! -e "$pkg/$cited" ]; then
      echo "MISSING: $cited (cited in $file)"
      missing=$((missing + 1))
    fi
  done < <(grep -oE '`(docs|examples)/[^`# ]+' "$file" | tr -d '`' | sort -u || true)
done

if [ "$missing" -gt 0 ]; then
  echo "$missing cited path(s) missing from $pkg" >&2
  exit 1
fi
echo "all cited docs/examples paths exist in $pkg"
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
chmod +x check-doc-paths.sh test-check-doc-paths.sh
bash test-check-doc-paths.sh
```

Expected: every line `ok   - …`, exit 0.

- [ ] **Step 5: Write `example-index.md`**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/references/example-index.md`:

````markdown
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
````

- [ ] **Step 6: Verify every path in all reference files against the installed pi**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev
bash scripts/check-doc-paths.sh SKILL.md references/decisions.md references/example-index.md
```

Expected: `all cited docs/examples paths exist in …`, exit 0. If any `MISSING:` line appears, open the real directory (`ls "$(bash scripts/locate-pi.sh | sed -n 's/^EXAMPLES=//p')/extensions"`), correct the citation in the offending file to the real name (or drop the row if the example no longer exists), and re-run until it passes. Do not silence the check.

- [ ] **Step 7: Commit**

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev/skills/pi-extension-dev
git commit -m "feat(pi-agent-dev): add example index and doc-path freshness check"
```

---

### Task 6: `typescript-best-practices` skill

**Files:**
- Create: `plugins/pi-agent-dev/skills/typescript-best-practices/SKILL.md`
- Create: `plugins/pi-agent-dev/skills/typescript-best-practices/references/language.md`
- Create: `plugins/pi-agent-dev/skills/typescript-best-practices/references/guidelines.md`

**Interfaces:**
- Consumes: nothing. Independent of pi; `guidelines.md` has one pi-specific section ("Running under jiti") as required by the spec.
- Produces: skill `typescript-best-practices`; `SKILL.md` refers to `references/language.md` and `references/guidelines.md`.

- [ ] **Step 1: Write `SKILL.md`**

Create `plugins/pi-agent-dev/skills/typescript-best-practices/SKILL.md`:

````markdown
---
name: typescript-best-practices
description: >-
  TypeScript language practices and coding guidelines for writing and reviewing
  TypeScript: strict compiler settings, narrowing over assertions, discriminated
  unions, validating unknown input at boundaries, async and AbortSignal
  cancellation, error handling, ESM import rules, module structure, tooling,
  test conventions, and a review checklist. Includes the constraints of code
  loaded through jiti (such as pi extensions), which transpiles without type
  checking. Use whenever writing, reviewing, refactoring, or configuring
  TypeScript (tsconfig, types, generics, async code, Node/ESM projects), even
  when the user only says "clean this up" or "review this .ts file".
---

# TypeScript best practices

Two references, read what the task needs:

- `references/language.md`: how to use the type system and async/error features well.
- `references/guidelines.md`: project conventions: structure, naming, imports, tooling, tests, the review checklist, and running under `jiti`.

## Writing TypeScript

1. Read the project's existing `tsconfig.json`, formatter, linter, and test setup first. **The project's conventions win** over anything here; only fill gaps.
2. Model the data with types before writing logic: unions for variants, `readonly` for data that should not change, `unknown` for anything from outside.
3. Narrow instead of asserting. If you write `as`, `!`, or `any`, you owe a one-line reason.
4. Make cancellation and cleanup explicit in every async API you add.
5. Typecheck (`tsc --noEmit`) before claiming the work is done; a passing runtime is not evidence of type soundness when a loader such as `jiti` skips type checking.

## Reviewing TypeScript

Apply the checklist at the end of `references/guidelines.md`. Report findings by severity, each with the file and line, the risk, and the concrete fix. Do not flag pure style points the project's formatter or linter already enforces.

## When asked about tooling

Recommend, do not impose: keep what the project already uses. For a new project the guidelines propose a default set, marked as a proposal.
````

- [ ] **Step 2: Write `references/language.md`**

Create `plugins/pi-agent-dev/skills/typescript-best-practices/references/language.md`:

````markdown
# TypeScript language practices

## Compiler settings

Start every project from `strict: true` and add:

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,   // arr[i] and record[key] are T | undefined
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "verbatimModuleSyntax": true,       // forces `import type` for type-only imports
    "isolatedModules": true,
    "noEmit": true                      // typecheck only when a loader/bundler transpiles
  }
}
```

`exactOptionalPropertyTypes` is worth enabling in new code (it separates "absent" from "explicitly undefined") but expect churn in existing code; adopt it deliberately, not by default.

## Model with types

- Variants are **discriminated unions**, not optional-field bags.

```ts
type Result =
  | { kind: "ok"; value: string }
  | { kind: "error"; message: string };

function render(r: Result): string {
  switch (r.kind) {
    case "ok": return r.value;
    case "error": return `error: ${r.message}`;
    default: return assertNever(r);
  }
}

function assertNever(x: never): never {
  throw new Error(`Unhandled variant: ${JSON.stringify(x)}`);
}
```

- Prefer unions of string literals (or an `as const` object) over `enum`.

```ts
const Level = { Info: "info", Warn: "warn" } as const;
type Level = (typeof Level)[keyof typeof Level];
```

- Use `readonly` and `ReadonlyArray<T>` for data that should not be mutated; copy on write when a value may be shared.
- Use `satisfies` to check a value against a type without widening it: `const routes = {...} satisfies Record<string, Handler>`.
- Derive types from a single source of truth (`typeof`, `keyof`, `ReturnType`, a schema's `Static<>`) instead of maintaining a parallel interface.

## Boundaries: `unknown`, not `any`

Anything from outside the program (JSON, `process.env`, network, files, user input, `catch` bindings, tool or plugin inputs) is `unknown` until validated.

```ts
function isUser(v: unknown): v is { id: string; name: string } {
  return typeof v === "object" && v !== null
    && typeof (v as Record<string, unknown>).id === "string"
    && typeof (v as Record<string, unknown>).name === "string";
}
```

For anything larger than a couple of fields, use a schema validator (for example TypeBox or zod) and infer the type from the schema, so the runtime check and the static type cannot drift.

- `any` disables checking and spreads; if unavoidable, confine it to one line with a comment saying why.
- `as` is an unchecked claim. Prefer a type guard, a schema check, or `satisfies`. A double assertion (`as unknown as T`) is a red flag.
- Non-null assertion `!` is acceptable only right after a check the compiler cannot see, with the reason evident from the adjacent line. Otherwise handle the `undefined`.

## Null and undefined

- Use `?.` and `??`, not `||` (which also swallows `0`, `""`, `false`).
- Return `undefined`/`null` for "not found" or throw for "should exist"; pick one per API and say which.
- With `noUncheckedIndexedAccess`, narrow before using indexed values: `const first = items[0]; if (first === undefined) return;`.

## Generics

- Constrain them (`<T extends { id: string }>`); an unconstrained `T` that you then cast is a smell.
- Use as few type parameters as the signature needs; if a parameter appears once, it is probably unnecessary.
- Do not build conditional-type puzzles to save a few lines; prefer overloads or two functions when the caller-facing signature stays clearer.

## Async

- Every promise is awaited, returned, or explicitly marked `void` with a reason. Enable `@typescript-eslint/no-floating-promises` (or the Biome equivalent).
- Accept an `AbortSignal` in any operation that can outlive its caller, pass it to `fetch`, child processes, timers, and nested calls, and check `signal.aborted` between steps.

```ts
async function fetchJson(url: string, signal?: AbortSignal): Promise<unknown> {
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`GET ${url} failed: ${res.status}`);
  return res.json();
}
```

- Release resources in `try/finally` so cancellation and errors take the same path; make cleanup idempotent.
- `Promise.all` fails fast and leaves the others running; use `Promise.allSettled` when you need every outcome, and bound concurrency for large fan-out.
- Do not mix `await` in `forEach`; use `for...of` for sequential work or `Promise.all(items.map(...))` for parallel work.
- Attach timeouts with `AbortSignal.timeout(ms)` rather than racing a `setTimeout` that never clears.

## Errors

- Throw `Error` (or a subclass), never strings. Preserve the original with `cause`.

```ts
try {
  await save(doc);
} catch (err: unknown) {
  throw new Error(`could not save ${doc.id}`, { cause: err });
}
```

- `catch` bindings are `unknown`: narrow with `err instanceof Error` before reading `.message`.
- Do not swallow errors silently. If ignoring is right (best-effort logging, cleanup), say so in a comment and keep the `catch` narrow.
- Model expected failures in the return type (`Result`-style union) when callers must handle them; throw for programmer errors and unrecoverable states.

## Things to avoid

- `enum`, `namespace`, and parameter properties in code that runs through type-stripping loaders (they need runtime transformation that some loaders do not perform).
- Default exports for library-style modules (harder to rename and grep). Exception: a framework that requires one, such as a pi extension's factory.
- Barrel files that re-export everything; they hide dependencies and slow type checking.
- Overusing `Partial`/`Pick`/`Omit` chains where a named type would read better.
````

- [ ] **Step 3: Write `references/guidelines.md`**

Create `plugins/pi-agent-dev/skills/typescript-best-practices/references/guidelines.md`:

````markdown
# TypeScript coding guidelines

The project's existing conventions always win. Everything marked "Proposal" is a default for new code, not a rule.

## Module and file structure

- One responsibility per file; split when a file needs a "and" to describe it or grows past what you can hold in your head.
- Separate pure logic from framework glue. Put decision logic in a plain module with no framework imports so it can be unit tested without the host. (Example: pi's `examples/extensions/plan-mode/` keeps `isSafeCommand` and step extraction in `utils.ts`, apart from the extension wiring in `index.ts`.)
- Keep side effects (I/O, timers, process spawning) at the edges; pass dependencies in rather than importing singletons in deep modules.
- Export the minimum; internal helpers stay unexported.

## Naming

- Types and classes `PascalCase`; values, functions, and variables `camelCase`; constants `SCREAMING_SNAKE_CASE` only for true module-level constants.
- Name booleans as questions (`isReady`, `hasUI`), functions as verbs, and avoid encoding types in names.
- No abbreviations a new reader would have to look up.

## Imports and modules (ESM)

- Use `import type { X }` for type-only imports (enforced by `verbatimModuleSyntax`).
- Use the `node:` prefix for built-ins (`node:fs/promises`).
- Match the resolution mode in use. Under Node's ESM resolution, relative imports need explicit file extensions. Loaders that run TypeScript directly (including the examples shipped with pi) import siblings with a `.ts` extension, which needs `allowImportingTsExtensions` when you typecheck with `noEmit`.
- Set `"type": "module"` in `package.json` for ESM packages.
- No circular imports; if two modules need each other, extract the shared piece.

## Error handling style

- Fail early at boundaries: validate input where it enters, then work with trusted types.
- Error messages say what failed and with what input, without leaking secrets.
- One place decides how errors surface to the user (log, notify, exit code); lower layers throw.

## Tooling

Follow what the project has. For a new project, the following is a proposal:

- **Typecheck:** `tsc --noEmit` as a `check`/`typecheck` script, run in CI and before commits.
- **Format and lint:** pick one setup and record it: Biome (single tool) or ESLint plus Prettier. Turn on a no-floating-promises rule and a no-explicit-any rule.
- **Tests:** Vitest (`vitest --run`) for unit tests; it runs TypeScript directly and mirrors what the pi project itself uses for its own tests.
- **Package manager and Node version:** commit the lockfile, and declare `engines.node`.

## Test conventions

- Test behavior through the public function, not private helpers.
- One assertion concept per test; name tests after the behavior (`rejects_empty_input`), not the function.
- Cover the boundary cases: empty input, `undefined`/`null`, the largest allowed size, cancellation (`AbortSignal` already aborted), and error paths.
- Fake time and I/O at the edge; keep pure logic tested with plain values.
- A type-level guarantee that matters gets a test too (`// @ts-expect-error` for calls that must not compile).

## Running under `jiti` (for example pi extensions)

Some hosts load `.ts` files through `jiti`, which transpiles TypeScript **without type checking**. Consequences:

- Type errors never surface at load. Run `tsc --noEmit` yourself (a `typecheck` script) with the host's packages installed as dev dependencies so its types resolve.
- Anything needing more than type stripping (`enum`, `namespace`) is riskier; use unions of literals.
- Keep `"type": "module"`. Runtime dependencies go in `dependencies`; packages the host supplies at runtime go in `peerDependencies` (`"*"`) and are not bundled.
- Use `import type` so the loader never tries to resolve a type-only import at runtime.
- Do a real load smoke test after typechecking; the type checker cannot see runtime resolution problems.

## Review checklist

Severity in brackets. For each finding give file:line, the risk, and the fix.

- [High] Unvalidated external data typed as a concrete type (`JSON.parse(...) as T`, `process.env.X as string`).
- [High] Floating or unhandled promises; missing `await` in `try/catch`; swallowed errors.
- [High] Long-running or cancellable work without `AbortSignal` propagation; resources not released in `finally`.
- [High] Shared mutable state mutated from concurrent code.
- [Medium] `any`, `as`, or `!` without a justification.
- [Medium] Optional-field bags where a discriminated union fits; missing exhaustive `default: assertNever`.
- [Medium] `||` used for defaults where `0`/`""`/`false` are valid values.
- [Medium] `catch (e)` reading `e.message` without narrowing.
- [Medium] Missing tests for empty input, error paths, or cancellation.
- [Low] Type-only imports without `import type`; missing `node:` prefix; barrel re-exports; default exports where none are required.
- [Low] Parallel interface that duplicates a schema or existing type.
````

- [ ] **Step 4: Structural checks**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/typescript-best-practices
head -3 SKILL.md | grep -q '^name: typescript-best-practices$' && echo name-ok
wc -l SKILL.md
grep -c '^## ' references/language.md references/guidelines.md
```

Expected: `name-ok`; `SKILL.md` under 150 lines; both references report several `##` headings.

- [ ] **Step 5: Compile-check the code samples**

The samples in `language.md` are meant to be valid TypeScript. Verify the ones that stand alone:

```bash
mkdir -p "$TMPDIR/tscheck" 2>/dev/null || mkdir -p /tmp/tscheck
cd "${TMPDIR:-/tmp}/tscheck"
cat > sample.ts <<'TS'
type Result =
  | { kind: "ok"; value: string }
  | { kind: "error"; message: string };

function assertNever(x: never): never {
  throw new Error(`Unhandled variant: ${JSON.stringify(x)}`);
}

export function render(r: Result): string {
  switch (r.kind) {
    case "ok": return r.value;
    case "error": return `error: ${r.message}`;
    default: return assertNever(r);
  }
}

const Level = { Info: "info", Warn: "warn" } as const;
export type Level = (typeof Level)[keyof typeof Level];

export function isUser(v: unknown): v is { id: string; name: string } {
  return typeof v === "object" && v !== null
    && typeof (v as Record<string, unknown>).id === "string"
    && typeof (v as Record<string, unknown>).name === "string";
}

export async function fetchJson(url: string, signal?: AbortSignal): Promise<unknown> {
  const res = await fetch(url, { signal });
  if (!res.ok) throw new Error(`GET ${url} failed: ${res.status}`);
  return res.json();
}

export async function save(doc: { id: string }): Promise<void> {
  try {
    await Promise.resolve(doc);
  } catch (err: unknown) {
    throw new Error(`could not save ${doc.id}`, { cause: err });
  }
}
TS
npx --yes -p typescript tsc --noEmit --strict --noUncheckedIndexedAccess --target es2022 --lib es2022,dom --module esnext --moduleResolution bundler sample.ts && echo samples-typecheck-ok
```

Expected: `samples-typecheck-ok`. If `tsc` reports errors, fix the sample in `language.md` (the doc, not the check) and re-run.

- [ ] **Step 6: Commit**

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev/skills/typescript-best-practices
git commit -m "feat(pi-agent-dev): add typescript-best-practices skill"
```

---

### Task 7: Evals, docs, and end-to-end verification

**Files:**
- Create: `plugins/pi-agent-dev/skills/pi-extension-dev/evals/evals.json`
- Create: `plugins/pi-agent-dev/skills/typescript-best-practices/evals/evals.json`
- Modify: `plugins/pi-agent-dev/README.md` (only if verification below shows a mismatch)

**Interfaces:**
- Consumes: skill names `pi-extension-dev`, `typescript-best-practices`; behaviors defined in Tasks 2–6.
- Produces: eval fixtures for the external eval harness (`skill-creator` workflow). `"files": []` throughout, matching this repo's existing evals.

- [ ] **Step 1: Write the `pi-extension-dev` evals**

Create `plugins/pi-agent-dev/skills/pi-extension-dev/evals/evals.json`:

```json
{
  "skill_name": "pi-extension-dev",
  "evals": [
    {
      "id": 0,
      "name": "confirm-force-push-gate",
      "prompt": "I use the pi coding agent. Write me a pi extension that asks for confirmation before the agent runs `git push --force` in bash, and blocks it if I say no.",
      "expected_output": "The session runs locate-pi.sh (or otherwise locates the installed @earendil-works/pi-coding-agent docs) and states the pi version, chooses a tool_call event handler (not a tool or command), and reads examples/extensions/permission-gate.ts before writing. The extension default-exports a factory taking ExtensionAPI, registers pi.on(\"tool_call\", ...) with no side effects in the factory, checks event.toolName === \"bash\" and the command for a force push, uses ctx.ui.confirm or ctx.ui.select when ctx.hasUI is true, and returns { block: true, reason } on refusal. When ctx.hasUI is false it blocks by default (fail safe) rather than allowing. Non-matching calls return undefined. It imports from @earendil-works/pi-coding-agent, never @mariozechner/pi-coding-agent. It tells the user how to load it (pi --extension ./file.ts) and mentions that pi loads via jiti without type checking so tsc --noEmit is a separate step.",
      "files": []
    },
    {
      "id": 1,
      "name": "branch-aware-counter-tool",
      "prompt": "Add a pi extension with a `counter` tool the model can call to increment or reset a named counter, and a /counters command that lists them. The counters need to be correct if I fork the session or go back in the tree.",
      "expected_output": "The session picks tool-result details as the storage (state that follows the active branch) rather than an external file or pi.appendEntry, and explains why. It reads examples/extensions/todo.ts first. The tool uses a TypeBox schema, with StringEnum from @earendil-works/pi-ai for the action (not Type.Union of Type.Literal), returns { content, details } with details holding the full counter state, and throws (not returns error text) on invalid input such as an unknown action. State is rebuilt on both session_start and session_tree by walking ctx.sessionManager.getBranch() and narrowing entries by type/role/toolName, not by scanning all entries. The /counters command guards ctx.mode !== \"tui\" if it uses a custom component, or uses ctx.ui.notify. No timers or processes are started in the factory.",
      "files": []
    },
    {
      "id": 2,
      "name": "tool-that-reloads",
      "prompt": "I want the agent itself to be able to trigger a reload of pi's extensions and skills after it edits one, via a tool it can call. Write that extension.",
      "expected_output": "The session recognizes that a tool receives ExtensionContext, which has no reload(), and that ctx.reload() exists only on ExtensionCommandContext (command handlers). It follows examples/extensions/reload-runtime.ts: registers a command that calls await ctx.reload() and treats it as terminal for the handler, plus a tool that queues the command with pi.sendUserMessage(\"/reload-runtime\", { deliverAs: \"followUp\" }). It does not call ctx.reload() from the tool and does not use state from the old runtime after reload.",
      "files": []
    },
    {
      "id": 3,
      "name": "embedding-request-defers-to-sdk-docs",
      "prompt": "I want to embed the pi coding agent in my Express server so each HTTP request runs a prompt and returns the answer. How should I do that?",
      "expected_output": "The session recognizes this is SDK embedding, not an extension. It says this plugin does not yet include an SDK-embedding skill, reads docs/sdk.md (and docs/cli-integration.md for the process-boundary alternatives) from the installed package, and answers with createAgentSession, session.prompt, and session.dispose in try/finally, using SessionManager.inMemory() if session files are not wanted and noting cwd. It does not invent an extension for this.",
      "files": []
    },
    {
      "id": 4,
      "name": "pi-not-installed-fallback",
      "prompt": "I don't have pi installed on this machine yet, but I want to draft a pi extension that shows the current git branch in the status line. Go ahead.",
      "expected_output": "locate-pi.sh reports not found (exit 1) or the session otherwise determines pi is not installed. The session tells the user and uses the upstream repo https://github.com/earendil-works/pi (packages/coding-agent docs and examples) as the source, and states that it could not confirm a version. It still chooses ctx.ui.setStatus with a stable key (from a session_start handler, running git via pi.exec), avoids starting a watcher or timer in the factory, and clears the status on session_shutdown. It does not silently fall back to the older @mariozechner/pi-coding-agent package or a docs URL it has not verified.",
      "files": []
    },
    {
      "id": 5,
      "name": "negative-unrelated-typescript-task",
      "prompt": "Refactor this function to use async/await instead of .then chains: function load(id){ return fetch('/api/'+id).then(r=>r.json()).then(d=>d.items); }",
      "expected_output": "The pi-extension-dev skill is not invoked; nothing about pi is mentioned. (typescript-best-practices may reasonably apply.) The function is rewritten with async/await.",
      "files": []
    }
  ]
}
```

- [ ] **Step 2: Write the `typescript-best-practices` evals**

Create `plugins/pi-agent-dev/skills/typescript-best-practices/evals/evals.json`:

```json
{
  "skill_name": "typescript-best-practices",
  "evals": [
    {
      "id": 0,
      "name": "review-flawed-snippet",
      "prompt": "Review this TypeScript for problems:\n\n```ts\nexport async function loadConfig(path: string) {\n  const raw = JSON.parse(await fs.promises.readFile(path, 'utf8')) as Config;\n  const port = raw.port || 8080;\n  fetch(raw.healthUrl);\n  try {\n    return await start(port);\n  } catch (e) {\n    console.log(e.message);\n  }\n}\n```",
      "expected_output": "The review flags, with concrete fixes: (1) JSON.parse(...) as Config is an unvalidated assertion of external data (High); use unknown plus a type guard or schema validation. (2) raw.port || 8080 swallows a valid port of 0 (Medium); use ??. (3) fetch(raw.healthUrl) is a floating promise with no error handling and no AbortSignal (High). (4) catch (e) reads e.message without narrowing from unknown (Medium) and the error is swallowed after logging, so the function returns undefined on failure (High). It does not nitpick formatting.",
      "files": []
    },
    {
      "id": 1,
      "name": "tsconfig-for-jiti-loaded-code",
      "prompt": "I'm writing a plugin that the host loads with jiti, so there's no build step. What tsconfig and scripts should I set up, and is there anything I should worry about?",
      "expected_output": "The answer says jiti transpiles without type checking, so type errors will not surface at load and a tsc --noEmit typecheck script is needed, with the host's packages installed as dev dependencies so types resolve. It recommends strict plus noUncheckedIndexedAccess and verbatimModuleSyntax (import type), noEmit, \"type\": \"module\", allowImportingTsExtensions if sibling imports use .ts extensions, peerDependencies for host-supplied packages, avoiding enum/namespace, and a real load smoke test after typechecking. It marks tooling choices (linter/formatter/test runner) as proposals and defers to existing project conventions.",
      "files": []
    },
    {
      "id": 2,
      "name": "cancellation-in-async-api",
      "prompt": "Write a TypeScript function that downloads a list of URLs in parallel and returns the parsed JSON for each. It needs to be cancellable and shouldn't blow up everything if one URL fails.",
      "expected_output": "The function accepts an AbortSignal and passes it to fetch, uses Promise.allSettled (or per-item error handling) so one failure does not reject the whole batch, returns a discriminated union per URL (ok with value / error with message) rather than mixing shapes, treats parsed JSON as unknown, throws Error with cause where it throws, and bounds concurrency or mentions doing so for large lists. No floating promises and no any.",
      "files": []
    },
    {
      "id": 3,
      "name": "negative-non-typescript-task",
      "prompt": "Write a Python script that renames all .jpeg files in a folder to .jpg.",
      "expected_output": "The typescript-best-practices skill is not invoked. A Python script is produced.",
      "files": []
    }
  ]
}
```

- [ ] **Step 3: Validate the eval JSON**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills
python3 - <<'PY'
import json
for skill in ("pi-extension-dev", "typescript-best-practices"):
    data = json.load(open(f"{skill}/evals/evals.json"))
    assert data["skill_name"] == skill
    ids = [e["id"] for e in data["evals"]]
    assert ids == sorted(set(ids)), ids
    for e in data["evals"]:
        assert set(e) == {"id", "name", "prompt", "expected_output", "files"}, e["name"]
        assert e["files"] == [], e["name"]
    print(skill, "ok", len(ids), "evals")
PY
```

Expected: `pi-extension-dev ok 6 evals` and `typescript-best-practices ok 4 evals`.

- [ ] **Step 4: Run all helper tests and the freshness check**

```bash
cd ~/projects/cc-marketplace/plugins/pi-agent-dev/skills/pi-extension-dev
bash scripts/test-locate-pi.sh && bash scripts/test-check-doc-paths.sh && \
bash scripts/check-doc-paths.sh SKILL.md references/decisions.md references/example-index.md
```

Expected: all test lines `ok`, then `all cited docs/examples paths exist in …`.

- [ ] **Step 5: Verify the plugin loads in Claude Code**

```bash
cd ~/projects/cc-marketplace
claude --plugin-dir ./plugins/pi-agent-dev -p "List the skills available from the pi-agent-dev plugin by exact name."
```

Expected: the output names `pi-agent-dev:pi-extension-dev` and `pi-agent-dev:typescript-best-practices`. If the flag combination is not supported by the installed `claude` version, start an interactive session with `claude --plugin-dir ./plugins/pi-agent-dev` and confirm both skills appear in `/plugin` or the skills list instead, and record which method was used.

- [ ] **Step 6: Run the evals with the skill-creator workflow**

Use the `skill-creator` skill to run each `evals.json` against its skill, review the transcripts against each `expected_output`, and iterate on the skill text (descriptions, `SKILL.md`, references) for any eval that fails. Record the final pass/fail per eval in the commit message body. Evals 5 (pi) and 3 (TypeScript) are the negative trigger checks: if either skill fires, tighten that skill's `description`. Re-run `scripts/check-doc-paths.sh` if a reference file changes.

- [ ] **Step 7: Reconcile README and commit**

Confirm `plugins/pi-agent-dev/README.md` still matches reality (skill names, deferred SDK skill, requirements); edit if not.

```bash
cd ~/projects/cc-marketplace
git add plugins/pi-agent-dev
git commit -m "test(pi-agent-dev): add evals for both skills"
```

- [ ] **Step 8: Final state check**

```bash
cd ~/projects/cc-marketplace
git status -sb
git log --oneline main..HEAD
```

Expected: clean working tree on `feat/pi-agent-dev`, with commits for the scaffold, `locate-pi.sh`, the SKILL.md entrypoint, decisions, example index and check script, the TypeScript skill, and the evals. Do not merge or push; hand the branch back for review.
