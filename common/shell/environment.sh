#!/usr/bin/env bash

DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
if [[ -z "${DOTFILES_PROFILE:-}" ]]; then
  if [[ -r "$DOTFILES_CONFIG_DIR/profile" ]]; then
    DOTFILES_PROFILE="$(<"$DOTFILES_CONFIG_DIR/profile")"
  else
    DOTFILES_PROFILE=personal
  fi
fi
if [[ -z "${DOTFILES_PLATFORM:-}" ]]; then
  if [[ -r "$DOTFILES_CONFIG_DIR/platform" ]]; then
    DOTFILES_PLATFORM="$(<"$DOTFILES_CONFIG_DIR/platform")"
  else
    case "$(uname -s)" in Darwin) DOTFILES_PLATFORM=macos ;; Linux) DOTFILES_PLATFORM=ubuntu ;; *) return 1 ;; esac
  fi
fi
case "$DOTFILES_PROFILE" in personal|work) ;; *) printf 'Invalid DOTFILES_PROFILE.\n' >&2; return 1 ;; esac
case "$DOTFILES_PLATFORM" in macos|ubuntu) ;; *) printf 'Invalid DOTFILES_PLATFORM.\n' >&2; return 1 ;; esac
export DOTFILES_CONFIG_DIR DOTFILES_PROFILE DOTFILES_PLATFORM
if [[ "${_DOTFILES_PLATFORM_APPLIED:-}" != "$DOTFILES_PLATFORM" ]]; then
  if [[ -r "$DOTFILES_CONFIG_DIR/platform.d/shell.sh" ]]; then
    source "$DOTFILES_CONFIG_DIR/platform.d/shell.sh"
  fi
  _DOTFILES_PLATFORM_APPLIED="$DOTFILES_PLATFORM"
fi
