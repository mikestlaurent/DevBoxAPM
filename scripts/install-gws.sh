#!/usr/bin/env bash
# install-gws.sh — Install Google Workspace CLI (gws) for DevBoxAPM.
#
# Called automatically by `apm install` via the postinstall hook.
# Also callable directly by engineers and automation tooling.
#
# Usage:
#   bash install-gws.sh [--check] [--json] [--quiet]
#
# Flags:
#   --check   Read-only probe. Reports state without installing. Never mutates.
#   --json    Emit a single JSON object to stdout instead of human text.
#   --quiet   Suppress all human-readable log output.
#
# Environment variables:
#   DEVBOX_APM_SKIP_GWS=1   Skip installation entirely (exit 0). Useful in
#                            headless CI where Workspace access is not needed.
#   DEVBOX_APM_VERBOSE=1     Force verbose output even when --quiet is set.
#
# Exit codes (stable contract):
#   0   gws is present (already installed or just installed successfully).
#   10  npm is missing; cannot install gws. No mutation occurred.
#   11  npm install command failed. Partial state possible.
#   20  No supported package manager available on this platform.

set -euo pipefail

# ── Flag parsing ─────────────────────────────────────────────────────────────
MODE_CHECK=false
MODE_JSON=false
MODE_QUIET=false

for arg in "$@"; do
  case "$arg" in
    --check)  MODE_CHECK=true ;;
    --json)   MODE_JSON=true ;;
    --quiet)  MODE_QUIET=true ;;
    *) echo "[devbox-apm] Unknown flag: $arg" >&2; exit 20 ;;
  esac
done

[[ "${DEVBOX_APM_VERBOSE:-0}" == "1" ]] && MODE_QUIET=false

# ── Helpers ───────────────────────────────────────────────────────────────────
log() {
  $MODE_QUIET && return
  if $MODE_JSON; then
    echo "[devbox-apm] $*" >&2
  else
    echo "[devbox-apm] $*"
  fi
}

# Emit structured JSON result and exit.
# Usage: json_exit <exit_code> <status> <gws_present> <gws_version|null> <action> <exit_reason>
json_exit() {
  local code=$1 status=$2 present=$3 version=$4 action=$5 reason=$6
  if $MODE_JSON; then
    printf '{"status":"%s","gws_present":%s,"gws_version":%s,"action":"%s","exit_reason":"%s"}\n' \
      "$status" "$present" "$version" "$action" "$reason"
  fi
  exit "$code"
}

# ── Skip guard ────────────────────────────────────────────────────────────────
if [[ "${DEVBOX_APM_SKIP_GWS:-0}" == "1" ]]; then
  log "DEVBOX_APM_SKIP_GWS=1 — skipping gws installation."
  json_exit 0 "skipped" "null" "null" "skipped" "DEVBOX_APM_SKIP_GWS set"
fi

# ── Detect current gws state ──────────────────────────────────────────────────
GWS_PRESENT=false
GWS_VERSION="null"

if command -v gws &>/dev/null; then
  GWS_PRESENT=true
  _ver=$(gws --version 2>/dev/null | head -1 || true)
  GWS_VERSION="\"${_ver:-unknown}\""
fi

# ── Check mode (read-only) ────────────────────────────────────────────────────
if $MODE_CHECK; then
  if $GWS_PRESENT; then
    log "gws is installed: $(gws --version 2>/dev/null | head -1 || echo 'version unknown')."
    json_exit 0 "present" "true" "$GWS_VERSION" "none" "already_installed"
  else
    if command -v npm &>/dev/null; then
      log "gws not found. Would install via: npm install -g @googleworkspace/cli"
      json_exit 0 "absent" "false" "null" "would_install_via_npm" "not_installed"
    else
      log "gws not found. npm is also missing — cannot install automatically."
      json_exit 0 "absent" "false" "null" "cannot_install" "npm_missing"
    fi
  fi
fi

# ── Already installed ─────────────────────────────────────────────────────────
if $GWS_PRESENT; then
  log "gws ${GWS_VERSION//\"/} is already installed — skipping."
  json_exit 0 "present" "true" "$GWS_VERSION" "skipped" "already_installed"
fi

# ── Install ───────────────────────────────────────────────────────────────────
log "Installing Google Workspace CLI (@googleworkspace/cli) ..."

if command -v npm &>/dev/null; then
  if npm install -g @googleworkspace/cli; then
    log "gws installed via npm."
    _new_ver=$(gws --version 2>/dev/null || true)
    json_exit 0 "installed" "true" "\"${_new_ver:-unknown}\"" "installed_via_npm" "success"
  else
    log "npm install failed. Check npm permissions or network access."
    json_exit 11 "error" "false" "null" "install_failed" "npm_install_error"
  fi
fi

# npm not found
log "npm not found. Install Node.js (https://nodejs.org) then run:"
log "  npm install -g @googleworkspace/cli"
log "Alternatively: nix run github:googleworkspace/cli"
json_exit 10 "error" "false" "null" "cannot_install" "npm_missing"
