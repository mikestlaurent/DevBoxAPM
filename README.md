# DevBoxAPM

> **AI agents:** See [AGENTS.md](AGENTS.md) for a machine-readable reference.

A configuration-driven distribution of agentic tools built on [Microsoft's Agent Package Manager (APM)](https://microsoft.github.io/apm/).

## Prerequisites

- Node.js 18+
- APM CLI: `npm install -g @microsoft/apm`

## Install

```bash
apm install mstlaure/DevBoxAPM#v0.5.0
```

APM resolves all dependencies, installs MCP servers, and deploys skills into the appropriate runtime directories.

## Dependencies

**Skills / plugins** (`apm.yml → dependencies.apm`):

| Package | Description |
|---|---|
| `obra/superpowers` | TDD, subagent, and parallel-agent skills |
| `anthropics/claude-code/plugins/code-review` | `/code-review` slash command |
| `anthropics/claude-code/plugins/security-guidance` | `/security-review` + pre-tool hook |
| `anthropics/claude-code/plugins/frontend-design` | `/frontend-design` slash command |
| `anthropics/claude-code/plugins/feature-dev` | `/feature-dev` slash command |
| `anthropics/claude-code/plugins/commit-commands` | `/commit` slash command |
| `anthropics/claude-code/plugins/pr-review-toolkit` | `/review-pr` slash command |
| `likec4/likec4/skills/likec4-dsl` | LikeC4 DSL reference for `.c4`/`.likec4` files |

**MCP servers** (`apm.yml → dependencies.mcp`):

| Package | How |
|---|---|
| `io.github.github/github-mcp-server` | Registry, user-scoped via `wire-mcp-user-scope.sh` |
| `app.linear/linear` | Registry; Code user-scoped via `wire-mcp-user-scope.sh`, Desktop via `wire-mcp-claude-desktop.sh`; auth via `/mcp` (Code) or browser OAuth (Desktop) |
| `likec4 mcp` | Built-in CLI subcommand, user-scoped via `wire-mcp-user-scope.sh` (requires Homebrew `likec4`) |

## Add a dependency

Edit `apm.yml` under `dependencies.apm` or `dependencies.mcp`, then run:

```bash
apm install
git add apm.yml apm.lock.yaml
git commit -m "chore: add <component>"
```

## Release

```bash
git tag v0.3.0 -m "<reason>"
git push origin v0.3.0
```

The [release workflow](.github/workflows/release.yml) packs a source zip and publishes a GitHub Release.

## Verify

```bash
apm install          # resolve and deploy locally
apm pack --dry-run   # confirm bundle builds cleanly
```
