#!/usr/bin/env bash
#
# Bootstrap a macOS machine for Vagrant development.
#
#   1. Installs Homebrew (or updates it if already present).
#   2. Installs VirtualBox with Homebrew.
#   3. Installs Vagrant with Homebrew.
#
# Re-running the script upgrades anything that is already installed.
#
# Usage:
#   ./bootstrap_macos.sh

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# Install a cask or formula, or upgrade it if it is already installed.
brew_install() {
    local kind="$1" name="$2"
    if brew list "$kind" "$name" >/dev/null 2>&1; then
        log "Upgrading $name"
        brew upgrade "$kind" "$name" || true
    else
        log "Installing $name"
        brew install "$kind" "$name"
    fi
}

main() {
    [[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
    [[ $EUID -eq 0 ]] && die "Run this script as a regular user, not root."

    # --- Homebrew ------------------------------------------------------------
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
        log "Updating Homebrew"
        brew update
    else
        # The installer also installs the Xcode Command Line Tools if missing.
        log "Installing Homebrew (you may be asked for your password)"
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        [[ -x "$BREW_PREFIX/bin/brew" ]] || die "Homebrew installation failed"
        eval "$("$BREW_PREFIX/bin/brew" shellenv)"
    fi

    # Put brew on PATH for future login shells (zsh is the macOS default).
    local shellenv_line="eval \"\$($BREW_PREFIX/bin/brew shellenv)\""
    if ! grep -qsF "$shellenv_line" "$HOME/.zprofile"; then
        log "Adding Homebrew to ~/.zprofile"
        printf '\n%s\n' "$shellenv_line" >> "$HOME/.zprofile"
    fi

    # --- VirtualBox ----------------------------------------------------------
    brew_install --cask virtualbox

    # --- Vagrant -------------------------------------------------------------
    # Alternative: install from HashiCorp's tap instead of the Homebrew cask.
    # brew tap hashicorp/tap
    # brew_install --formula hashicorp/tap/hashicorp-vagrant
    brew_install --cask vagrant

    log "Installed tools:"
    brew --version | head -n 1
    printf 'VirtualBox %s\n' "$(VBoxManage --version)"
    vagrant --version
}

set -euo pipefail
main
log "Done. Open a new terminal (or run the command below) to get brew on your PATH:"
printf '    eval "$(%s/bin/brew shellenv)"\n' "$BREW_PREFIX"
if [[ "$(uname -m)" != "arm64" ]]; then
    log "If VirtualBox reports a blocked kernel extension, allow Oracle in"
    printf '    System Settings > Privacy & Security, then reboot.\n'
fi
