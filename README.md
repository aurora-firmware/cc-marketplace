# cc-marketplace

A Claude Code plugin marketplace with an initial `github-utils` plugin.

## Structure

This repository follows Claude Code's marketplace layout:

- `.claude-plugin/marketplace.json`
- `plugins/github-utils/.claude-plugin/plugin.json`
- `plugins/github-utils/skills/gh-cli/`
- `plugins/github-utils/skills/pr-review/`

## Included plugin

`github-utils` bundles these existing skills:

- `gh-cli`
- `pr-review`

They are currently copied into the plugin as-is so the plugin is self-contained when installed.

## Local install and test

From this repository root in Claude Code:

```text
/plugin marketplace add .
/plugin install github-utils@cc-marketplace
```

Then use:

```text
/github-utils:gh-cli
/github-utils:pr-review
```

For direct development testing without marketplace install:

```bash
claude --plugin-dir ./plugins/github-utils
```
