# DevBoxAPM

> **AI agents:** See [AGENTS.md](AGENTS.md) for a structured, machine-readable reference.

```yaml
# Quick facts
install: "apm install mstlaure/DevBoxAPM#v0.1.0"
components: 8        # 7 plugins, 1 MCP server
runtimes: [claude-code, cursor, codex, opencode, gemini-cli]
manifest: apm.yml    # only file engineers need to edit
```

A configuration-driven distribution of agentic tools built on [Microsoft's Agent Package Manager (APM)](https://microsoft.github.io/apm/). Engineers update one file — `apm.yml` — to control which Claude Code plugins, cross-runtime skills, and MCP servers are bundled and released.

---

## What's included

| Component | Source | Kind | Slash command |
|---|---|---|---|
| [superpowers](https://github.com/obra/superpowers) | `obra/superpowers` | Plugin (all runtimes) | — |
| [code-review](https://github.com/anthropics/claude-code/tree/main/plugins/code-review) | `anthropics/claude-code/plugins/code-review` | Plugin (Claude Code) | `/code-review` |
| [security-guidance](https://github.com/anthropics/claude-code/tree/main/plugins/security-guidance) | `anthropics/claude-code/plugins/security-guidance` | Plugin (Claude Code) | `/security-review` |
| [frontend-design](https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design) | `anthropics/claude-code/plugins/frontend-design` | Plugin (Claude Code) | `/frontend-design` |
| [feature-dev](https://github.com/anthropics/claude-code/tree/main/plugins/feature-dev) | `anthropics/claude-code/plugins/feature-dev` | Plugin (Claude Code) | `/feature-dev` |
| [commit-commands](https://github.com/anthropics/claude-code/tree/main/plugins/commit-commands) | `anthropics/claude-code/plugins/commit-commands` | Plugin (Claude Code) | `/commit` |
| [pr-review-toolkit](https://github.com/anthropics/claude-code/tree/main/plugins/pr-review-toolkit) | `anthropics/claude-code/plugins/pr-review-toolkit` | Plugin (Claude Code) | `/review-pr` |
| [GitHub MCP](https://github.com/github/github-mcp-server) | `io.github.github/github-mcp-server` | MCP server | auto-wired |

---

## Install

### Prerequisites

- Node.js 18+
- [APM CLI](https://microsoft.github.io/apm/getting-started/quick-start/): `npm install -g @microsoft/apm`

### Install in a project

```bash
apm install mstlaure/DevBoxAPM#v0.1.0
```

APM resolves all dependencies, deploys plugins into `.claude/` (Claude Code) and `.agents/` (cross-runtime), and wires the GitHub MCP server into every detected client config.

---

## Update

### Add or remove a component

`apm.yml` is the single source of truth. Edit the `dependencies` block:

```yaml
dependencies:
  apm:
    - obra/superpowers
    - anthropics/claude-code/plugins/code-review
    - anthropics/claude-code/plugins/security-guidance
    - anthropics/claude-code/plugins/frontend-design
    - anthropics/claude-code/plugins/feature-dev
    - anthropics/claude-code/plugins/commit-commands
    - anthropics/claude-code/plugins/pr-review-toolkit
    # - some-org/new-plugin
  mcp:
    - io.github.github/github-mcp-server
```

Then refresh the lockfile and commit:

```bash
apm install
git add apm.yml apm.lock.yaml
git commit -m "chore: add some-org/new-plugin"
```

### Pin exact versions

```yaml
- obra/superpowers#v1.4.0
- anthropics/claude-code/plugins/code-review#abc1234
```

### Release a new version

```bash
git tag v0.2.0 -m "Add some-org/new-plugin"
git push origin v0.2.0
```

The [release workflow](.github/workflows/release.yml) runs automatically: it packs the bundle and creates a GitHub Release. Consumers update by referencing the new tag.

---

## Verify

```bash
apm install              # resolve and deploy locally
apm pack --dry-run       # verify the bundle builds cleanly
```

---

## Integration recipes

### Dockerfile — ephemeral agent runner

```dockerfile
FROM node:20-slim

RUN npm install -g @microsoft/apm

WORKDIR /workspace
RUN apm install mstlaure/DevBoxAPM#v0.1.0

CMD ["bash"]
```

### devcontainer.json — Codespaces / VS Code Dev Containers

```json
{
  "name": "DevBoxAPM",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/devcontainers/features/node:1": { "version": "20" }
  },
  "postCreateCommand": "npm install -g @microsoft/apm && apm install mstlaure/DevBoxAPM#v0.1.0"
}
```

### Consumer GitHub Action — install DevBoxAPM in another repo's CI

```yaml
# .github/workflows/agentic-setup.yml
name: Agentic setup

on: [push]

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install DevBoxAPM
        run: |
          npm install -g @microsoft/apm
          apm install mstlaure/DevBoxAPM#v0.1.0
```

---

## Stable contracts

These interfaces are stable across semver-compatible releases. Automation tooling may rely on them.

### File paths

| Path | Role |
|------|------|
| `apm.yml` | Manifest — edit to add/remove components |
| `apm.lock.yaml` | Lockfile — commit after every `apm install` |
| `.claude/` | Claude Code deploy target (gitignored) |
| `.agents/` | Cross-runtime deploy target (gitignored) |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `apm: command not found` | APM CLI not installed | `npm install -g @microsoft/apm` |
| `apm.lock.yaml` drift in CI | Lockfile not committed after local `apm install` | `apm install && git add apm.lock.yaml && git commit` |

---

## Repository structure

```
DevBoxAPM/
├── apm.yml                         # Edit this to change the distribution
├── apm.lock.yaml                   # Auto-generated; commit after `apm install`
├── AGENTS.md                       # Structured reference for AI agents
├── .apm/                           # Reserved for future local primitives
└── .github/
    └── workflows/
        ├── validate.yml            # PR gate: lockfile sync + pack dry-run
        └── release.yml             # Tag push: pack + GitHub Release
```
