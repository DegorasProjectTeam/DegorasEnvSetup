#!/usr/bin/env bash

# ====================================================================
# DEGORAS ENVIRONMENT BOOTSTRAP FOR MSYS2/UCRT64
# --------------------------------------------------------------------
# Author: Angel Vera Herrera
# Updated: 07/11/2025
# Version: 251107
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

echo "[INFO] DEGORAS ENVIRONMENT BOOTSTRAP FOR MSYS2/UCRT64"

# Resolve script directory and env file
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ENV_FILE="${SCRIPT_DIR}/degoras-env-variables.env"

# Check env file
if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] Environment variable file not found: $ENV_FILE"
    return 1 2>/dev/null || exit 1
fi

echo "[INFO] Loading UCRT64 environment..."
# Load MSYS2 UCRT64 environment
source shell ucrt64

# Restore custom title
printf "\033]0;DEGORAS ENV\007"

# Prompt and colors
PS1="\[\033]0;DEGORAS ENV\007\]\[\033[1;32m\][DEGORAS-ENV]\$\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\]\n\$ "
export PS1

echo "[INFO] Loading DEGORAS environment from: $ENV_FILE"

# Load key=value pairs from env file, converting Windows paths
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2-)

    # Normalize Windows paths to Unix if possible
    if [[ "$value" =~ ^[A-Za-z]: ]] && command -v cygpath >/dev/null 2>&1; then
        unix_path=$(cygpath -u "$value" 2>/dev/null)
        if [[ -n "$unix_path" ]]; then
            export "$key=$unix_path"
            echo "  $key=$unix_path"
        else
            export "$key=$value"
            echo "  $key=$value (no conversion)"
        fi
    else
        export "$key=$value"
        echo "  $key=$value"
    fi
done < "$ENV_FILE"

# Add vcpkg to PATH if available
if [[ -n "$VCPKG_ROOT" && -d "$VCPKG_ROOT" ]]; then
    export PATH="$VCPKG_ROOT:$PATH"
    echo "  PATH += $VCPKG_ROOT"
fi

# Sanea posibles \r del .env (CRLF)
for k in VCPKG_ROOT VCPKG_DEFAULT_TRIPLET VCPKG_DEFAULT_HOST_TRIPLET MSYS2_ROOT UCRT64_ROOT MINGW_ROOT DEGORAS_DEVDRIVE; do
  eval "export $k=\"\${$k%$'\r'}\""
done

# Normaliza backslashes si el .env trae rutas tipo T:\...
for k in VCPKG_ROOT VCPKG_DEFAULT_BINARY_CACHE VCPKG_OVERLAY_PORTS VCPKG_OVERLAY_TRIPLETS MSYS2_ROOT UCRT64_ROOT MINGW_ROOT DEGORAS_DEPLOYS DEGORAS_WORKSPACE; do
  eval "val=\${$k}"
  [ -n "$val" ] && eval "export $k=\"\${val//\\\\/\/}\""
done

# Helper para no duplicar rutas en PATH
add_path_once() { case ":$PATH:" in *":$1:"*) ;; *) PATH="$1:$PATH";; esac; }

# Prepend vcpkg/bin usando ruta MSYS
if [ -n "$VCPKG_ROOT" ]; then
  triplet="${VCPKG_DEFAULT_TRIPLET:-$VCPKG_DEFAULT_HOST_TRIPLET}"
  if [ -z "$triplet" ]; then triplet="x64-mingw-dynamic-degoras"; fi
  vcpkg_root_unix="$(cygpath -u "$VCPKG_ROOT" 2>/dev/null || printf '%s' "$VCPKG_ROOT")"
  vcpkg_bin="$vcpkg_root_unix/installed/$triplet/bin"
  if [ -d "$vcpkg_bin" ]; then
    add_path_once "$vcpkg_bin"
    echo "  PATH += $vcpkg_bin"
  else
    echo "[WARN] vcpkg bin not found: $vcpkg_bin"
  fi
fi

# Sanea PATH por si arrastra \r
PATH="$(printf '%s' "$PATH" | tr -d '\r')"
export PATH

# --------------------------------------------------------------------
# Normalize DEGORAS_DEVDRIVE and prepare logs
# --------------------------------------------------------------------
if [[ -z "${DEGORAS_DEVDRIVE}" ]]; then
    echo "[WARN] DEGORAS_DEVDRIVE is not set by env file; using HOME."
    DEGORAS_DEVDRIVE="$HOME"
fi
DEGORAS_DEVDRIVE="${DEGORAS_DEVDRIVE%/}"
export DEGORAS_DEVDRIVE

LOGS_ROOT="${DEGORAS_DEVDRIVE}/logs"
ENV_LOG_DIR="${LOGS_ROOT}/env"
mkdir -p "${ENV_LOG_DIR}"

# --------------------------------------------------------------------
# Persistent history
# --------------------------------------------------------------------
shopt -s histappend
export HISTFILE="${ENV_LOG_DIR}/bash_history"
export HISTSIZE=50000
export HISTFILESIZE=200000
export HISTCONTROL=ignoredups:erasedups
export HISTIGNORE="ls:cd:pwd:clear:history*"
export HISTTIMEFORMAT="%F %T "

PROMPT_COMMAND='history -a; history -n; '"$PROMPT_COMMAND"
export PROMPT_COMMAND

# Enable prefix search with arrow keys
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

echo "[INFO] Persistent history: ${HISTFILE}"

# --------------------------------------------------------------------
# Logging configuration
# --------------------------------------------------------------------
echo "[INFO] Logs root: ${LOGS_ROOT}"
echo "[INFO] Env logs : ${ENV_LOG_DIR}"

# --------------------------------------------------------------------
# Change to devdrive root
# --------------------------------------------------------------------
if [[ -d "$DEGORAS_DEVDRIVE" ]]; then
    cd "$DEGORAS_DEVDRIVE"
fi

clear
echo "[INFO] DEGORAS-PROJECT environment ready."

# --------------------------------------------------------------------
# Full session transcript (preferred) or per-command fallback
# --------------------------------------------------------------------
if command -v script >/dev/null 2>&1; then
    SESSION_LOG="${ENV_LOG_DIR}/session_$(date +%Y%m%d_%H%M%S).log"
    export SHELL=/usr/bin/bash
    export BASH_ENV="/dev/null"
    exec script -qaf "${SESSION_LOG}"
else
    CMDLOG="${ENV_LOG_DIR}/commands_$(date +%Y%m%d).log"
    echo "[WARN] 'script' not found. Using per-command logging to: ${CMDLOG}"

    per_command_trap() {
        printf "%s | %s\n" "$(date +%F\ %T)" "$(history 1 | sed 's/^ *[0-9]\+ *//')" >> "$CMDLOG"
    }
    trap per_command_trap DEBUG

    echo "[INFO] Command logging active. Press Ctrl+D to exit."
    return 0 2>/dev/null || exit 0
fi
