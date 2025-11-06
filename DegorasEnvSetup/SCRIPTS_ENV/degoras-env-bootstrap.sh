#!/usr/bin/env bash

# ====================================================================
# DEGORAS-PROJECT ENVIRONMENT BOOTSTRAP FOR MSYS2/UCRT64
# --------------------------------------------------------------------
# Author: Angel Vera Herrera
# Updated: 26/10/2025
# Version: 251026
# --------------------------------------------------------------------
# © Degoras Project Team
# ====================================================================

echo "[INFO] DEGORAS-PROJECT ENVIRONMENT BOOTSTRAP FOR MSYS2/UCRT64"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ENV_FILE="${SCRIPT_DIR}/degoras-env-variables.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] Environment variable file not found: $ENV_FILE"
    return 1
fi

echo "[INFO] Loading UCRT64 environment..."
source shell ucrt64

# Restore custom title
printf "\033]0;DEGORAS-PROJECT ENV\007"

# Custom promptcd
export PS1="\[\033]0;DEGORAS-PROJECT ENV\007\]\[\033[1;32m\][DEGORAS-ENV]\$\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\]\n\$ "

echo "[INFO] Loading DEGORAS-PROJECT environment from: $ENV_FILE"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty or comment lines
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2-)

    # Normalize Windows paths
    if [[ "$value" =~ ^[A-Za-z]: ]]; then
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

echo "[INFO] DEGORAS-PROJECT environment ready."

cd $DEGORAS_DEVDRIVE

clear
