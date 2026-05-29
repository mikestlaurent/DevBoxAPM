#!/usr/bin/env bash
# wire-mcp-user-scope.sh — DevBoxAPM post-install step
#
# Ensures the GitHub MCP server is registered at user scope (root mcpServers)
# in ~/.claude.json so it is available in every Claude Code session regardless
# of working directory.
#
# Migration: if a project-scope 'github' entry exists in ~/.claude.json it is
# moved to user scope and removed from all project entries.
#
# Idempotent — running multiple times is a no-op after the first successful run.
# Non-destructive — backs up ~/.claude.json before the first write; aborts if
# the file is not valid JSON rather than writing a broken partial result.
# Safe — only touches entries named 'github'; never modifies other MCP servers.
#
# Usage: bash wire-mcp-user-scope.sh
# Called by: Mac-Dev-setup apm:install and apm:update tasks.

set -euo pipefail

CLAUDE_JSON="${HOME}/.claude.json"
MCP_NAME="github"
DEVBOX_MCP_JSON="${HOME}/.devbox-apm/.mcp.json"

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

# ── Detect current state ──────────────────────────────────────────────────────

USER_HAS=$(jq -r --arg n "${MCP_NAME}" \
  'if (.mcpServers // {})[$n] != null then "yes" else "no" end' \
  "${CLAUDE_JSON}")

# Collect project paths that have a project-scope github entry (bash 3.2 safe)
PROJ_PATHS=()
while IFS= read -r _path; do
  [[ -n "${_path}" ]] && PROJ_PATHS+=("${_path}")
done < <(jq -r --arg n "${MCP_NAME}" \
  '(.projects // {}) | to_entries[] | select(.value.mcpServers[$n] != null) | .key' \
  "${CLAUDE_JSON}" 2>/dev/null || true)

# Already correct — user-scope present, no project-scope stragglers
if [[ "${USER_HAS}" == "yes" ]] && [[ "${#PROJ_PATHS[@]}" -eq 0 ]]; then
  echo "[mcp-scope] ${MCP_NAME} already at user scope — nothing to do"
  exit 0
fi

# ── Backup before first write ─────────────────────────────────────────────────

BACKUP="${CLAUDE_JSON}.bak-$(date +%Y%m%d%H%M%S)"
cp "${CLAUDE_JSON}" "${BACKUP}"
echo "[mcp-scope] Backup: ${BACKUP}"

# ── Determine config to write at user scope ───────────────────────────────────

if [[ "${USER_HAS}" == "no" ]]; then
  MCP_CONFIG=""

  # Prefer existing project-scope config — preserves PAT and command choice
  if [[ "${#PROJ_PATHS[@]}" -gt 0 ]]; then
    MCP_CONFIG=$(jq -c --arg n "${MCP_NAME}" --arg p "${PROJ_PATHS[0]}" \
      '.projects[$p].mcpServers[$n]' "${CLAUDE_JSON}" 2>/dev/null || echo "")
  fi

  # Fall back to APM-deployed .mcp.json (HTTP transport, no token required)
  if [[ -z "${MCP_CONFIG}" ]] || [[ "${MCP_CONFIG}" == "null" ]]; then
    if [[ -f "${DEVBOX_MCP_JSON}" ]] && jq empty "${DEVBOX_MCP_JSON}" 2>/dev/null; then
      MCP_CONFIG=$(jq -c \
        '.mcpServers | to_entries[] | select(.value.type == "http") | .value | del(.id)' \
        "${DEVBOX_MCP_JSON}" 2>/dev/null | head -1 || echo "")
    fi
  fi

  # Hard default: HTTP transport via GitHub Copilot OAuth
  if [[ -z "${MCP_CONFIG}" ]] || [[ "${MCP_CONFIG}" == "null" ]]; then
    MCP_CONFIG='{"type":"http","url":"https://api.githubcopilot.com/mcp/","headers":{}}'
    echo "[mcp-scope] WARNING: no existing config found — registering HTTP default"
  fi

  TMP=$(mktemp)
  jq --arg n "${MCP_NAME}" --argjson cfg "${MCP_CONFIG}" \
    '.mcpServers[$n] = $cfg' "${CLAUDE_JSON}" > "${TMP}" && mv "${TMP}" "${CLAUDE_JSON}"
  echo "[mcp-scope] Registered ${MCP_NAME} at user scope"
fi

# ── Remove project-scope entries ──────────────────────────────────────────────

for _p in "${PROJ_PATHS[@]}"; do
  TMP=$(mktemp)
  jq --arg n "${MCP_NAME}" --arg p "${_p}" \
    'del(.projects[$p].mcpServers[$n])' "${CLAUDE_JSON}" > "${TMP}" && mv "${TMP}" "${CLAUDE_JSON}"
  echo "[mcp-scope] Removed project-scope ${MCP_NAME} from: ${_p}"
done

echo "[mcp-scope] Done"
