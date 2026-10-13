#!/usr/bin/env bash

set -euo pipefail
PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == --dry-run ]]; then
  printf 'Would install missing macOS packages from %s/Brewfile.\n' "$PLATFORM_DIR"
  exit 0
fi
[[ "$#" == 0 ]] || { printf 'Usage: bash platforms/macos/setup.sh [--dry-run]\n' >&2; exit 2; }
brew_bin="$(command -v brew || true)"
if [[ -z "$brew_bin" ]]; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then brew_bin="$candidate"; break; fi
  done
fi
if [[ -z "$brew_bin" ]]; then
  installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  /bin/bash -c "$installer"
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then brew_bin="$candidate"; break; fi
  done
fi
[[ -n "$brew_bin" ]] || { printf 'Homebrew executable is missing.\n' >&2; exit 1; }
brew_environment="$("$brew_bin" shellenv)"
eval "$brew_environment"
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 \
  "$brew_bin" bundle install --no-upgrade --file="$PLATFORM_DIR/Brewfile"
