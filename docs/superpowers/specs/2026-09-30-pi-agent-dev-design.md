# pi-agent-dev Plugin Design

## Goal

Add a `pi-agent-dev` plugin to this marketplace that gives a Claude Code session the context to build extensions for the pi coding agent (`@earendil-works/pi-coding-agent`): where the official docs are, how to make sound architectural decisions on the pi SDK, and TypeScript best practices.

## Scope

- New plugin `plugins/pi-agent-dev/` and a matching entry in `.claude-plugin/marketplace.json`
- Skills: `pi-extension-dev`, `typescript-best-practices`
- Deferred (not built now): `pi-sdk-embedding`
- Out of scope: an agent (add later only if isolated "audit this extension" reviews are wanted); skills for themes, keybindings, or providers (routing-table rows point at the pi docs until real use justifies a skill)

## Design Decisions

### Skills, not an agent

The requirement is to give the *current session* context. Skills load into the session; an agent runs isolated and returns only a summary.

### Do not copy the pi docs

Pi ships `docs/` and `examples/` inside its npm package. Copying them into the plugin would go stale and need a sync mechanism. Instead the skill reads them from the installed package, so they always match the version the user runs.

- Canonical package: `@earendil-works/pi-coding-agent`. (`@mariozechner/pi-coding-agent` is the older name and must not be used.)
- Resolve at runtime: `$(npm root -g)/@earendil-works/pi-coding-agent/{docs,examples}`; record the version from its `package.json` in the session.
- Fallback when pi is not installed or the docs are missing: the upstream repo `https://github.com/earendil-works/pi` (`docs/`) at the tag matching the desired version. No published docs-site URL has been verified, so none is hardcoded.
- The skill carries only a **quick reference**: a task → doc/example routing table plus the few core contracts.

### One TypeScript skill, two references

Language practices and coding guidelines are always wanted together, so they are one skill with two references. Split later only if it grows. Pi-specific typing (tool parameter schemas, event handlers, extension state) lives in `pi-extension-dev`, keeping `typescript-best-practices` useful outside pi.

## Plugin Structure

```
plugins/pi-agent-dev/
  .claude-plugin/plugin.json
  README.md
  skills/
    pi-extension-dev/
      SKILL.md
      references/
        decisions.md        # curated architecture judgment
        example-index.md    # task -> examples/extensions/* file
    typescript-best-practices/
      SKILL.md
      references/
        language.md
        guidelines.md
```

Manifests follow the `github-utils` conventions (name, description, version `1.0.0`, author, keywords, MIT license, `category: Developer Tools` in the marketplace entry).

## Skill: `pi-extension-dev`

**Triggers on:** writing, modifying, debugging, or reviewing pi extensions; questions about how to build something on pi.

**Procedure (SKILL.md, kept short, progressive disclosure):**

1. **Locate docs and version.** Resolve the installed package path, read its version, and fall back to the upstream repo if absent.
2. **Choose the integration point.** Decide between extension, skill, prompt template, pi package, or custom provider using `decisions.md` and the pi docs' "Choose an integration point" section. If the need is embedding pi in another app, say the SDK skill is not yet available and read `docs/sdk.md` directly.
3. **Apply the contracts checklist** from `docs/extensions.md`: runtime lifecycle (including that code after `ctx.reload()` must not reuse old-runtime state), events and concurrency, tools and dynamic activation, context and session changes, state, UI and modes, errors and cleanup.
4. **Start from the closest example.** Use `example-index.md` to pick a file in `examples/extensions/` and read it before writing code.
5. **Type it well.** Apply pi-specific typing patterns; defer general TypeScript guidance to `typescript-best-practices`.
6. **Verify.** Load with `pi --extension ./file.ts`, exercise it, reload, and confirm cleanup.

**Quick reference (in SKILL.md):** the default-export factory receiving `ExtensionAPI`; `jiti` means no compile step (and therefore no type checking at load); distributed extensions use pi packages with a `pi.extensions` entry in `package.json`; task → doc routing table.

**References:** `decisions.md` holds curated, opinionated architecture judgment and points to docs instead of restating them; `example-index.md` maps tasks to example files. Both must be validated against the installed docs when written, since examples change between versions.

## Skill: `typescript-best-practices`

**Triggers on:** writing or reviewing TypeScript, in or outside pi.

- `language.md`: strict `tsconfig`, narrowing over `as` assertions, discriminated unions, `unknown` plus runtime validation at boundaries, generics discipline, async and `AbortSignal` cancellation and cleanup, error typing.
- `guidelines.md`: module and file structure, naming, error-handling style, ESM import rules (`import type`, explicit extensions), lint/format tooling, test conventions, and a review checklist.
- Pi constraints called out explicitly: extensions run through `jiti`, which transpiles without type checking, so projects should run `tsc --noEmit` themselves; extension packages are ESM (`"type": "module"`).

Concrete tooling recommendations (linter, test runner) are proposals to be decided during implementation, not fixed by this spec.

## Testing

Skills are validated with evals, as `pr-review` and `changelog` do (`evals/` directories, using the `skill-creator` workflow):

- `pi-extension-dev`: given "add a command that ...", the session locates the installed docs, picks an integration point, reads a matching example, and produces an extension that loads under `pi --extension`.
- `typescript-best-practices`: given a snippet with known issues, the review names them.
- Trigger-description checks so each skill fires on its intended prompts and not on unrelated work.

## Open Items

- Confirm `@earendil-works/pi-coding-agent` layout stability (docs/examples paths) before hardcoding paths in the skill; the skill should degrade gracefully if paths move.
- Decide whether `pi-sdk-embedding` is built once SDK embedding becomes a real need.
