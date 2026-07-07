# Claude Marketplace Bootstrap Design

## Goal

Bootstrap this repository as a working Claude Code plugin marketplace with one plugin, `github-utils`, that bundles the existing `gh-cli` and `pr-review` skills without modifying their contents.

## Scope

- Add the root marketplace manifest at `.claude-plugin/marketplace.json`
- Add a `github-utils` plugin under `plugins/github-utils/`
- Copy the selected skills and their referenced resources into the plugin
- Add basic documentation for local testing and installation

## Structure

The repository will follow Claude Code's documented marketplace layout:

- `.claude-plugin/marketplace.json`
- `plugins/github-utils/.claude-plugin/plugin.json`
- `plugins/github-utils/skills/gh-cli/...`
- `plugins/github-utils/skills/pr-review/...`
- `plugins/github-utils/README.md`

## Design Decisions

### Bundle the skills into the plugin

Installed plugins are copied into Claude Code's cache, so the plugin must contain its own copies of `gh-cli` and `pr-review`. Referencing `~/.claude/skills` at runtime would break after installation.

### Preserve the selected skills as-is

The first version should be a baseline package. The copied skill content should remain unchanged so later edits can be reviewed explicitly.

### Keep manifests minimal

The initial manifests should declare only the metadata needed to install and use the marketplace:

- marketplace name and owner
- plugin name, description, and version
- relative plugin source path from the marketplace root

## User Flow

1. Add the marketplace from the repository root directory
2. Install `github-utils` from the marketplace
3. Use the namespaced skills:
   - `/github-utils:gh-cli`
   - `/github-utils:pr-review`

## Testing

Validation for the bootstrap should be lightweight:

- confirm the expected files and directories exist
- validate the JSON manifests parse correctly
- verify the copied skill folders are present under the plugin

## Risks

- The upstream local skills may evolve later, so the bundled copies can drift from `~/.claude/skills`
- `pr-review` depends on the GitHub CLI and authentication at runtime, but that is a usage prerequisite rather than a packaging blocker
