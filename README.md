# DevBoxAPM

> **AI agents:** See [AGENTS.md](AGENTS.md) for a structured, machine-readable reference.

```yaml
# Quick facts
install: "apm install mstlaure/DevBoxAPM#v0.1.0"
components: 6        # 4 plugins, 1 MCP server, 1 CLI binary
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
| [GitHub MCP](https://github.com/github/github-mcp-server) | `io.github.github/github-mcp-server` | MCP server | auto-wired |
| [Google Workspace CLI](https://github.com/googleworkspace/cli) | `@googleworkspace/cli` (npm) | CLI binary (postinstall) | `gws mcp` |

---

## Install

### Prerequisites

- Node.js 18+
- [APM CLI](https://microsoft.github.io/apm/getting-started/quick-start/): `npm install -g @microsoft/apm`

### Install in a project

```bash
apm install mstlaure/DevBoxAPM#v0.1.0
```

APM resolves all dependencies, deploys plugins into `.claude/` (Claude Code) and `.agents/` (cross-runtime), wires the GitHub MCP server into every detected client config, and runs `scripts/install-gws.sh` to install the Google Workspace CLI.

### Skip GWS in headless CI

```bash
DEVBOX_APM_SKIP_GWS=1 apm install mstlaure/DevBoxAPM#v0.1.0
```

### Authenticate Google Workspace

```bash
gws auth login
```

To expose GWS as an MCP server so agents can call Workspace APIs directly:

```bash
gws mcp                            # all services
gws mcp -s drive,gmail,calendar    # specific services
```

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
bash scripts/install-gws.sh --check --json   # probe gws state (read-only)
```

---

## Integration recipes

### Dockerfile — ephemeral agent runner

```dockerfile
FROM node:20-slim

RUN npm install -g @microsoft/apm

WORKDIR /workspace
RUN apm install mstlaure/DevBoxAPM#v0.1.0

ENV DEVBOX_APM_SKIP_GWS=1   # no interactive auth in containers

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
  "postCreateCommand": "npm install -g @microsoft/apm && apm install mstlaure/DevBoxAPM#v0.1.0",
  "remoteEnv": {
    "DEVBOX_APM_SKIP_GWS": "1"
  }
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
        env:
          DEVBOX_APM_SKIP_GWS: '1'
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
| `scripts/install-gws.sh` | GWS install entry point |
| `.claude/` | Claude Code deploy target (gitignored) |
| `.agents/` | Cross-runtime deploy target (gitignored) |

### Environment variables

| Variable | Effect |
|----------|--------|
| `DEVBOX_APM_SKIP_GWS=1` | Skip gws installation; exit 0. Use in headless CI. |
| `DEVBOX_APM_VERBOSE=1` | Force verbose output from `install-gws.sh`. |

### `install-gws.sh` flags

| Flag | Effect |
|------|--------|
| `--check` | Read-only probe; reports state without mutating. |
| `--json` | Emit structured JSON to stdout (see [AGENTS.md](AGENTS.md#contracts)). |
| `--quiet` | Suppress human-readable log output. |

### Exit codes — `install-gws.sh`

| Code | Meaning |
|------|---------|
| `0` | gws is present or installation succeeded |
| `10` | npm not found; cannot install |
| `11` | npm install failed |
| `20` | Unrecognized flag or no supported package manager |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `apm: command not found` | APM CLI not installed | `npm install -g @microsoft/apm` |
| `gws: command not found` after install | npm missing during postinstall | Install Node.js, then `bash scripts/install-gws.sh` |
| `install-gws.sh` exits `10` | npm not on PATH | Install Node.js from https://nodejs.org |
| `apm.lock.yaml` drift in CI | Lockfile not committed after local `apm install` | `apm install && git add apm.lock.yaml && git commit` |
| Workspace MCP tools not available | GWS not running as MCP server | Run `gws mcp` before starting your agent |

---

## Repository structure

```
DevBoxAPM/
├── apm.yml                         # Edit this to change the distribution
├── apm.lock.yaml                   # Auto-generated; commit after `apm install`
├── AGENTS.md                       # Structured reference for AI agents
├── scripts/
│   └── install-gws.sh              # Postinstall: installs gws CLI (supports --check --json)
├── .apm/                           # Reserved for future local primitives
└── .github/
    └── workflows/
        ├── validate.yml            # PR gate: lockfile sync + pack dry-run
        └── release.yml             # Tag push: pack + GitHub Release
```
