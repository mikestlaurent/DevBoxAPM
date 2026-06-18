#!/usr/bin/env bash
# wire-mcp-linear.sh — DevBoxAPM post-install step
#
# Registers the Linear MCP server for both Claude Code CLI (user scope) and
# Claude Desktop. Linear hosts its own remote MCP endpoint and is not in any
# APM/MCP registry, so wiring is handled here rather than in apm.yml.
#
# Claude Code:
#   Registers via `claude mcp add --transport http --scope user` so the server
#   is available in every Claude Code session regardless of working directory.
#   Removes the legacy `linear-server` entry if present (name unification).
#   Auth: first use triggers browser OAuth via /mcp in Claude Code. Registration
#   is automated; the OAuth handshake itself is not.
#
# Claude Desktop:
#   Desktop has no native remote-HTTP transport, so the server is wrapped with
#   the `npx -y mcp-remote` stdio shim. Auth: mcp-remote opens a browser for
#   Linear OAuth on first connect after a Desktop restart.
#
# Idempotent — running multiple times is a no-op after the first successful run.
# Non-destructive — backs up claude_desktop_config.json before any write; aborts
# if the file exists but is not valid JSON.
# Safe — only touches the `linear` key in Desktop config; never modifies other
# servers or preferences.
#
# Usage: bash wire-mcp-linear.sh
# Called by: Mac-Dev-setup apm:install and apm:update tasks.

set -euo pipefail

# Normalize Homebrew prefix for Apple Silicon (/opt/homebrew) vs Intel (/usr/local).
# Parent task shells often don't inherit the user's interactive PATH.
if [[ "$(uname -m)" == "arm64" ]] && [[ -d /opt/homebrew/bin ]]; then
  export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${PATH}"
elif [[ -d /usr/local/bin ]]; then
  export PATH="/usr/local/bin:${PATH}"
fi
echo "[mcp-linear] arch=$(uname -m) PATH normalized"

# Runs a command with a deadline. Uses gtimeout (coreutils), timeout (macOS 13+),
# or falls back to no-op if neither is available.
_with_timeout() {
  local secs=$1; shift
  if command -v gtimeout &>/dev/null; then
    gtimeout "$secs" "$@"
  elif command -v timeout &>/dev/null; then
    timeout "$secs" "$@"
  else
    "$@"
  fi
}

LINEAR_URL="https://mcp.linear.app/mcp"
NAME="linear"
LEGACY_NAME="linear-server"
DESKTOP_CONFIG="${HOME}/Library/Application Support/Claude/claude_desktop_config.json"
DESKTOP_CONFIG_DIR="${HOME}/Library/Application Support/Claude"
DESKTOP_APP="/Applications/Claude.app"

# ── Part A: Claude Code CLI (user scope) ──────────────────────────────────────

if ! command -v claude &>/dev/null; then
  echo "[mcp-linear] WARNING: claude CLI not found on PATH — skipping Claude Code registration"
else
  # Idempotency: check if already registered at user scope with correct URL
  existing=$(_with_timeout 15 claude mcp get "${NAME}" 2>/dev/null || echo "")
  if echo "${existing}" | grep -q "${LINEAR_URL}"; then
    echo "[mcp-linear] ${NAME} already registered in Claude Code — skipping"
  else
    _with_timeout 30 claude mcp add --transport http --scope user "${NAME}" "${LINEAR_URL}"
    echo "[mcp-linear] Registered ${NAME} in Claude Code at user scope"
  fi

  # Legacy cleanup: remove linear-server if it points to the same endpoint
  legacy=$(_with_timeout 15 claude mcp get "${LEGACY_NAME}" 2>/dev/null || echo "")
  if echo "${legacy}" | grep -q "mcp.linear.app"; then
    _with_timeout 15 claude mcp remove --scope user "${LEGACY_NAME}" 2>/dev/null || true
    echo "[mcp-linear] Removed legacy ${LEGACY_NAME} entry from Claude Code"
  fi
fi

# ── Part B: Claude Desktop ────────────────────────────────────────────────────

if [[ ! -d "${DESKTOP_CONFIG_DIR}" ]] && [[ ! -e "${DESKTOP_APP}" ]]; then
  echo "[mcp-linear] Claude Desktop not found — skipping Desktop registration"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "[mcp-linear] ERROR: jq is required for Desktop config update but not found on PATH" >&2
  exit 1
fi

# Bootstrap empty config if file doesn't exist yet
if [[ ! -f "${DESKTOP_CONFIG}" ]]; then
  mkdir -p "${DESKTOP_CONFIG_DIR}"
  echo '{}' > "${DESKTOP_CONFIG}"
fi

if ! jq empty "${DESKTOP_CONFIG}" 2>/dev/null; then
  echo "[mcp-linear] ERROR: ${DESKTOP_CONFIG} is not valid JSON — aborting to avoid data loss" >&2
  exit 1
fi

DESIRED_ENTRY='{"command":"npx","args":["-y","mcp-remote","https://mcp.linear.app/mcp"]}'

# Idempotency: skip if already correct
current_entry=$(jq -c --arg n "${NAME}" '(.mcpServers // {})[$n] // empty' \
  "${DESKTOP_CONFIG}" 2>/dev/null || echo "")
if [[ "$(jq -cS . <<<"${DESIRED_ENTRY}" 2>/dev/null)" == \
      "$(jq -cS . <<<"${current_entry}" 2>/dev/null)" ]] && \
   [[ -n "${current_entry}" ]]; then
  echo "[mcp-linear] ${NAME} already configured in Claude Desktop — skipping"
  exit 0
fi

BACKUP="${DESKTOP_CONFIG}.bak-$(date +%Y%m%d%H%M%S)"
cp "${DESKTOP_CONFIG}" "${BACKUP}"
echo "[mcp-linear] Desktop config backup: ${BACKUP}"

TMP=$(mktemp)
jq --arg n "${NAME}" --argjson cfg "${DESIRED_ENTRY}" \
  '.mcpServers[$n] = $cfg' "${DESKTOP_CONFIG}" > "${TMP}" && mv "${TMP}" "${DESKTOP_CONFIG}"
echo "[mcp-linear] Registered ${NAME} in Claude Desktop"

echo "[mcp-linear] Done"
