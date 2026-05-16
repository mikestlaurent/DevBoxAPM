# AGENTS.md — DevBoxAPM

Machine-readable reference for AI agents and automation tooling consuming this repository.
Human engineers: see [README.md](README.md).

---

## Package

```yaml
name: devbox-apm
manifest: apm.yml                  # authoritative dependency manifest
lockfile: apm.lock.yaml
package_manager: apm  # npm install -g @microsoft/apm
install_command: "apm install mstlaure/DevBoxAPM#v0.2.0"
```

---

## Dependencies

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

  mcp:
    - io.github.github/github-mcp-server
```

---

## Commands

| Intent | Command |
|--------|---------|
| Install DevBoxAPM | `apm install mstlaure/DevBoxAPM#v0.2.0` |
| Verify install state | `apm install && apm pack --dry-run` |
| Add a dependency | Edit `dependencies` in `apm.yml`, then `apm install` |
| Release a new version | `git tag vX.Y.Z -m "<reason>" && git push origin vX.Y.Z` |
| Validate lockfile is in sync | `apm install && git diff --exit-code apm.lock.yaml` |
