#!/usr/bin/env bash
#
# Bootstrap a Linux machine for Ansible development.
#
#   1. Installs uv and uses it to install the latest stable CPython.
#   2. Creates ~/.ansible-dev-tools with a virtual environment in ~/.ansible-dev-tools/.venv.
#   3. Activates the venv and installs ansible-dev-tools into it.
#
# Usage:
#   ./bootstrap_linux.sh          # run; prints how to activate the venv afterwards
#   source ./bootstrap_linux.sh   # run and leave the venv active in the current shell

ADT_DIR="$HOME/.ansible-dev-tools"
VENV_DIR="$ADT_DIR/.venv"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

install_pkg() {
    local sudo=""
    [[ $EUID -ne 0 ]] && sudo="sudo"

    if command -v apt-get >/dev/null; then
        $sudo apt-get update -y && $sudo apt-get install -y "$@"
    elif command -v dnf >/dev/null; then
        $sudo dnf install -y "$@"
    elif command -v yum >/dev/null; then
        $sudo yum install -y "$@"
    elif command -v zypper >/dev/null; then
        $sudo zypper --non-interactive install "$@"
    elif command -v pacman >/dev/null; then
        $sudo pacman -Sy --noconfirm "$@"
    elif command -v apk >/dev/null; then
        $sudo apk add "$@"
    else
        die "No supported package manager found; please install: $*"
    fi
}

python_version() { "$1" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))'; }

main() {
    [[ $EUID -eq 0 ]] && die "Run this script as a regular user, not root."

    if ! command -v curl >/dev/null; then
        log "Installing curl"
        install_pkg curl ca-certificates
    fi

    # --- uv ------------------------------------------------------------------
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null; then
        log "Updating uv"
        uv self update || true
    else
        log "Installing uv"
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
    command -v uv >/dev/null || die "uv installation failed"

    # --- Python --------------------------------------------------------------
    log "Installing the latest Python"
    uv python install --default || uv python install
    local python_bin
    # --system ignores any active/nearby venv so we get the real interpreter.
    python_bin="$(uv python find --system --no-project --managed-python)"
    log "Using Python $(python_version "$python_bin") at $python_bin"

    # --- Virtual environment -------------------------------------------------
    mkdir -p "$ADT_DIR"

    if [[ -d "$VENV_DIR" ]]; then
        local venv_ver=""
        venv_ver="$(python_version "$VENV_DIR/bin/python" 2>/dev/null || true)"
        if [[ "$venv_ver" != "$(python_version "$python_bin")" ]]; then
            log "Existing venv uses Python ${venv_ver:-unknown}; recreating it"
            rm -rf "$VENV_DIR"
        fi
    fi

    if [[ ! -d "$VENV_DIR" ]]; then
        log "Creating virtual environment in $VENV_DIR"
        "$python_bin" -m venv "$VENV_DIR"
    fi

    # shellcheck disable=SC1091
    source "$VENV_DIR/bin/activate"

    # --- Ansible development tools -------------------------------------------
    log "Installing ansible-dev-tools"
    python -m pip install --upgrade pip
    python -m pip install --upgrade ansible-dev-tools

    log "Installed tools:"
    adt --version
}

# When sourced, run the setup in a subshell so strict mode and `exit` can't
# kill the caller's shell, then activate the venv in the caller's shell.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    if (set -euo pipefail; main); then
        # shellcheck disable=SC1091
        source "$VENV_DIR/bin/activate"
        log "Done. The virtual environment is active in this shell."
    else
        printf 'Bootstrap failed.\n' >&2
        return 1
    fi
else
    set -euo pipefail
    main
    log "Done. Activate the environment with:"
    printf '    source %s/bin/activate\n' "$VENV_DIR"
fi
