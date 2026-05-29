#!/usr/bin/env bash
# wire-mcp-user-scope.sh — DevBoxAPM post-install step
#
# Ensures the listed MCP servers are registered at user scope (root mcpServers)
# in ~/.claude.json so they are available in every Claude Code session regardless
# of working directory.
#
# Migration: if a project-scope entry exists in ~/.claude.json it is moved to
# user scope and removed from all project entries.
#
# Idempotent — running multiple times is a no-op after the first successful run.
# Non-destructive — backs up ~/.claude.json before the first write; aborts if
# the file is not valid JSON rather than writing a broken partial result.
# Safe — only touches entries named in MCP_NAMES; never modifies other MCP servers.
#
# Usage: bash wire-mcp-user-scope.sh
# Called by: Mac-Dev-setup apm:install and apm:update tasks.

set -euo pipefail

CLAUDE_JSON="${HOME}/.claude.json"
DEVBOX_MCP_JSON="${HOME}/.devbox-apm/.mcp.json"

# Servers to promote to user scope
MCP_NAMES=("github" "likec4")

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
  echo "[mcp-scope] ERROR: jq is required but not found on PATH" >&2
  exit 1
fi

if [[ ! -f "${CLAUDE_JSON}" ]]; then
  echo "[mcp-scope] ~/.claude.json not found — skipping MCP user-scope wiring"
  exit 0
fi

if ! jq empty "${CLAUDE_JSON}" 2>/dev/null; then
  echo "[mcp-scope] ERROR: ~/.claude.json is not valid JSON — aborting to avoid data loss" >&2
  exit 1
fi

# ── Detect whether any work is needed ────────────────────────────────────────

needs_write=false
for name in "${MCP_NAMES[@]}"; do
  user_has=$(jq -r --arg n "${name}" \
    'if (.mcpServers // {})[$n] != null then "yes" else "no" end' \
    "${CLAUDE_JSON}")

  proj_count=$(jq -r --arg n "${name}" \
    '(.projects // {}) | to_entries[] | select(.value.mcpServers[$n] != null) | .key' \
    "${CLAUDE_JSON}" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "${user_has}" == "no" ]] || [[ "${proj_count}" -gt 0 ]]; then
    needs_write=true
    break
  fi
done

if [[ "${needs_write}" == "false" ]]; then
  echo "[mcp-scope] All servers already at user scope — nothing to do"
  exit 0
fi

# ── Backup before first write ─────────────────────────────────────────────────

BACKUP="${CLAUDE_JSON}.bak-$(date +%Y%m%d%H%M%S)"
cp "${CLAUDE_JSON}" "${BACKUP}"
echo "[mcp-scope] Backup: ${BACKUP}"

# ── Process each server ───────────────────────────────────────────────────────

for name in "${MCP_NAMES[@]}"; do
  user_has=$(jq -r --arg n "${name}" \
    'if (.mcpServers // {})[$n] != null then "yes" else "no" end' \
    "${CLAUDE_JSON}")

  # Collect project paths that have a project-scope entry (bash 3.2 safe)
  proj_paths=()
  while IFS= read -r _path; do
    [[ -n "${_path}" ]] && proj_paths+=("${_path}")
  done < <(jq -r --arg n "${name}" \
    '(.projects // {}) | to_entries[] | select(.value.mcpServers[$n] != null) | .key' \
    "${CLAUDE_JSON}" 2>/dev/null || true)

  # Already correct — user-scope present, no project-scope stragglers
  if [[ "${user_has}" == "yes" ]] && [[ "${#proj_paths[@]}" -eq 0 ]]; then
    echo "[mcp-scope] ${name} already at user scope — skipping"
    continue
  fi

  # ── Determine config to write at user scope ─────────────────────────────────

  if [[ "${user_has}" == "no" ]]; then
    mcp_config=""

    # Priority 1: existing project-scope config — preserves any token/command
    if [[ "${#proj_paths[@]}" -gt 0 ]]; then
      mcp_config=$(jq -c --arg n "${name}" --arg p "${proj_paths[0]}" \
        '.projects[$p].mcpServers[$n]' "${CLAUDE_JSON}" 2>/dev/null || echo "")
    fi

    # Priority 2: APM-deployed .mcp.json — match by server name
    if [[ -z "${mcp_config}" ]] || [[ "${mcp_config}" == "null" ]]; then
      if [[ -f "${DEVBOX_MCP_JSON}" ]] && jq empty "${DEVBOX_MCP_JSON}" 2>/dev/null; then
        mcp_config=$(jq -c --arg n "${name}" \
          '.mcpServers[$n] // empty | del(.id)' \
          "${DEVBOX_MCP_JSON}" 2>/dev/null || echo "")
      fi
    fi

    # Priority 3: hard default — github only (HTTP transport via GitHub Copilot OAuth)
    if [[ -z "${mcp_config}" ]] || [[ "${mcp_config}" == "null" ]]; then
      if [[ "${name}" == "github" ]]; then
        mcp_config='{"type":"http","url":"https://api.githubcopilot.com/mcp/","headers":{}}'
        echo "[mcp-scope] WARNING: no existing config found for ${name} — registering HTTP default"
      else
        echo "[mcp-scope] WARNING: no config found for ${name} — skipping"
        continue
      fi
    fi

    TMP=$(mktemp)
    jq --arg n "${name}" --argjson cfg "${mcp_config}" \
      '.mcpServers[$n] = $cfg' "${CLAUDE_JSON}" > "${TMP}" && mv "${TMP}" "${CLAUDE_JSON}"
    echo "[mcp-scope] Registered ${name} at user scope"
  fi

  # ── Remove project-scope entries ─────────────────────────────────────────────

  for _p in "${proj_paths[@]}"; do
    TMP=$(mktemp)
    jq --arg n "${name}" --arg p "${_p}" \
      'del(.projects[$p].mcpServers[$n])' "${CLAUDE_JSON}" > "${TMP}" && mv "${TMP}" "${CLAUDE_JSON}"
    echo "[mcp-scope] Removed project-scope ${name} from: ${_p}"
  done
done

echo "[mcp-scope] Done"
