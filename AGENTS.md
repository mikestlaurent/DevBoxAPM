# AGENTS.md — DevBoxAPM

Machine-readable reference for AI agents and automation tooling consuming this repository.
Human engineers: see [README.md](README.md) for guided instructions.

---

## Package

```yaml
name: devbox-apm
manifest: apm.yml
lockfile: apm.lock.yaml
package_manager: apm  # npm install -g @microsoft/apm
install_command: "apm install mstlaure/DevBoxAPM#<tag>"
runtimes:
  - claude-code       # deploys to .claude/
  - cursor
  - codex
  - opencode
  - gemini-cli        # cross-runtime deploys to .agents/
versioning: semver    # pin consumers to #vX.Y.Z tags
```

---

## Components

```yaml
components:
  - name: superpowers
    kind: plugin
    source: obra/superpowers
    upstream_url: https://github.com/obra/superpowers
    runtimes: [claude-code, cursor, codex, opencode, gemini-cli]

  - name: code-review
    kind: plugin
    source: anthropics/claude-code/plugins/code-review
    upstream_url: https://github.com/anthropics/claude-code/tree/main/plugins/code-review
    runtimes: [claude-code]
    slash_command: /code-review

  - name: security-guidance
    kind: plugin
    source: anthropics/claude-code/plugins/security-guidance
    upstream_url: https://github.com/anthropics/claude-code/tree/main/plugins/security-guidance
    runtimes: [claude-code]
    slash_command: /security-review
    hook: pre-tool  # warns on unsafe code patterns before edits are applied

  - name: frontend-design
    kind: plugin
    source: anthropics/claude-code/plugins/frontend-design
    upstream_url: https://github.com/anthropics/claude-code/tree/main/plugins/frontend-design
    runtimes: [claude-code]
    slash_command: /frontend-design

  - name: github-mcp
    kind: mcp-server
    source: io.github.github/github-mcp-server
    upstream_url: https://github.com/github/github-mcp-server
    runtimes: [claude-code, cursor, codex, opencode, gemini-cli]
    wired_automatically: true  # apm wires into all detected client configs

```

---

## Commands

| Intent | Command |
|--------|---------|
| Install DevBoxAPM in a project | `apm install mstlaure/DevBoxAPM#v0.1.0` |
| Verify install state | `apm install && apm pack --dry-run` |
| Add a new dependency | Edit `dependencies.apm` or `dependencies.mcp` in `apm.yml`, then run `apm install` |
| Pin a dependency to an exact version | Append `#vX.Y.Z` to its entry in `apm.yml`, then run `apm install` |
| Release a new version | `git tag vX.Y.Z -m "<reason>" && git push origin vX.Y.Z` |
| Validate lockfile is in sync | `apm install && git diff --exit-code apm.lock.yaml` |

---

## Contracts

### Stable file paths

| Path | Role | Mutable by engineers? |
|------|------|-----------------------|
| `apm.yml` | Manifest — single source of truth for all dependencies | Yes |
| `apm.lock.yaml` | Generated lockfile — commit after every `apm install` | No (generated) |
| `.claude/` | Claude Code deploy target (gitignored) | No (generated) |
| `.agents/` | Cross-runtime deploy target (gitignored) | No (generated) |
| `apm_modules/` | Resolved dependency cache (gitignored) | No (generated) |

### Versioning

- Releases use **semver** git tags (`v1.2.3`).
- Consumers should pin to a tag: `apm install mstlaure/DevBoxAPM#v0.1.0`.
- `apm.lock.yaml` pins exact resolved commits for all transitive dependencies.

---

## Capability map

> When you need to… use this component.

| Task | Component | Invocation |
|------|-----------|-----------|
| Review a PR for code quality, bugs, CLAUDE.md compliance | code-review | `/code-review` or `/code-review --comment` |
| Audit code for security vulnerabilities | security-guidance | `/security-review` (also runs automatically as a pre-tool hook) |
| Build or style a frontend UI component | frontend-design | `/frontend-design` |
| Structured software development with TDD / subagent orchestration | superpowers | Available after install; see [obra/superpowers](https://github.com/obra/superpowers) |
| Interact with GitHub (issues, PRs, repos) via MCP tools | github-mcp | Wired automatically into detected clients; no slash command needed |

---

## Integration recipes

See [README.md § Integration recipes](README.md#integration-recipes) for copy-pasteable snippets covering:

- **Dockerfile** — ephemeral agent runner with DevBoxAPM pre-installed
- **devcontainer.json** — Codespaces / VS Code Dev Containers
- **Consumer GitHub Action** — install DevBoxAPM in another repo's CI pipeline
