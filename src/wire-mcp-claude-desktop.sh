#!/usr/bin/env bash
# wire-mcp-claude-desktop.sh — DevBoxAPM post-install step (Claude Desktop counterpart)
#
# Registers the Linear MCP server in Claude Desktop's claude_desktop_config.json
# using an `npx mcp-remote` stdio wrapper (Desktop does not support remote HTTP
# directly).
#
# Safety contract (mirrors wire-mcp-user-scope.sh):
#   - No-op if Claude Desktop is not installed.
#   - Validates JSON before writing; aborts rather than corrupt the file.
#   - Backs up the config before the first write.
#   - Idempotent — re-running after a successful install is a no-op.
#   - Only touches the "linear" key; never modifies other MCP servers.
#
# Auth: `mcp-remote` opens a browser for the Linear OAuth flow on first connect
# (after Desktop is restarted). Registration is automated; the handshake is not.
#
# Usage: bash wire-mcp-claude-desktop.sh
# Called by: Mac-Dev-setup apm:install and apm:update tasks.

set -euo pipefail

DESKTOP_APP="/Applications/Claude.app"
CONFIG_DIR="${HOME}/Library/Application Support/Claude"
CONFIG_FILE="${CONFIG_DIR}/claude_desktop_config.json"

SERVER_KEY="linear"
SERVER_ENTRY='{"command":"npx","args":["-y","mcp-remote","https://mcp.linear.app/mcp"]}'

# ── Prerequisites ─────────────────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
  echo "[desktop-mcp] ERROR: jq is required but not found on PATH" >&2
  exit 1
fi

# ── Desktop presence check ────────────────────────────────────────────────────

if [[ ! -d "${DESKTOP_APP}" ]] && [[ ! -d "${CONFIG_DIR}" ]]; then
  echo "[desktop-mcp] Claude Desktop not found — skipping claude_desktop_config.json update"
  exit 0
fi

# ── Bootstrap empty config if it doesn't exist yet ───────────────────────────

if [[ ! -f "${CONFIG_FILE}" ]]; then
  mkdir -p "${CONFIG_DIR}"
  echo '{}' > "${CONFIG_FILE}"
fi

# ── Validate JSON ─────────────────────────────────────────────────────────────

if ! jq empty "${CONFIG_FILE}" 2>/dev/null; then
  echo "[desktop-mcp] ERROR: ${CONFIG_FILE} is not valid JSON — aborting to avoid data loss" >&2
  exit 1
fi

# ── Idempotency check ─────────────────────────────────────────────────────────

current=$(jq -c --arg k "${SERVER_KEY}" '.mcpServers[$k] // empty' "${CONFIG_FILE}" 2>/dev/null || true)

if [[ "${current}" == "${SERVER_ENTRY}" ]]; then
  echo "[desktop-mcp] ${SERVER_KEY} already configured in Claude Desktop — nothing to do"
  exit 0
fi

# ── Backup before first write ─────────────────────────────────────────────────

BACKUP="${CONFIG_FILE}.bak-$(date +%Y%m%d%H%M%S)"
cp "${CONFIG_FILE}" "${BACKUP}"
echo "[desktop-mcp] Backup: ${BACKUP}"

# ── Write entry ───────────────────────────────────────────────────────────────

TMP=$(mktemp)
jq --arg k "${SERVER_KEY}" --argjson v "${SERVER_ENTRY}" \
  '.mcpServers[$k] = $v' "${CONFIG_FILE}" > "${TMP}" && mv "${TMP}" "${CONFIG_FILE}"
echo "[desktop-mcp] Registered ${SERVER_KEY} in Claude Desktop — restart Desktop to activate"
echo "[desktop-mcp] Done"
