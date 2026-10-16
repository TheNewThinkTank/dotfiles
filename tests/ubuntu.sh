#!/usr/bin/env bash

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 26.04 ]] || { printf 'This runner requires Ubuntu 26.04.\n' >&2; exit 1; }
export DOTFILES_PLATFORM=ubuntu
if [[ -n "${DOTFILES_DOCKER_CA_FILE:-}" ]]; then
  [[ -r "$DOTFILES_DOCKER_CA_FILE" ]] || { printf 'Approved CA bundle is unreadable.\n' >&2; exit 1; }
  export CURL_CA_BUNDLE="$DOTFILES_DOCKER_CA_FILE"
  export GIT_SSL_CAINFO="$DOTFILES_DOCKER_CA_FILE"
  export NODE_EXTRA_CA_CERTS="$DOTFILES_DOCKER_CA_FILE"
  export SSL_CERT_FILE="$DOTFILES_DOCKER_CA_FILE"
fi
profiles=(personal work)
if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
  case "$DOTFILES_PROFILE" in personal|work) profiles=("$DOTFILES_PROFILE") ;; *) printf 'Invalid profile.\n' >&2; exit 1 ;; esac
fi
if [[ "${DOTFILES_PACKAGE_SET:-workstation}" == homelab ]]; then
  check_homelab_profile() {
      local HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME XDG_CACHE_HOME
      local PATH="$PATH"
      local backup_count expected_version
      HOME="$(mktemp -d /tmp/dotfiles-homelab-XXXXXX)"
      export HOME
      export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state"
      export XDG_DATA_HOME="$HOME/.local/share" XDG_CACHE_HOME="$HOME/.cache"
      export PATH="$HOME/.local/bin:$PATH"
      bash "$REPO_ROOT/bootstrap.sh" --force --platform ubuntu --profile "$1" --package-set homelab
      bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile "$1" --package-set homelab
      backup_count="$(find "$XDG_STATE_HOME/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)"
      bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile "$1" --package-set homelab
      [[ "$(find "$XDG_STATE_HOME/dotfiles/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)" == "$backup_count" ]]
      expected_version="$(jq -r '.assets.kubectl.version' "$REPO_ROOT/platforms/ubuntu/tools.lock.json")"
      [[ "$(kubectl version --client --output=json | jq -r '.clientVersion.gitVersion')" == "v$expected_version" ]]
      if command -v oc >/dev/null || command -v ghostty >/dev/null; then
        printf 'The homelab package set unexpectedly installed workstation tools.\n' >&2
        exit 1
      fi
      zsh -dfi -c 'source "$HOME/.zshenv"; source "$HOME/.zshrc"; [[ -n ${functions[compdef]-} && "$EDITOR" == nvim ]]'
      printf 'Native Ubuntu homelab checks passed for: %s\n' "$1"
      rm -rf -- "$HOME"
  }
  for profile in "${profiles[@]}"; do
    check_homelab_profile "$profile"
  done
  exit 0
fi
bash "$REPO_ROOT/platforms/ubuntu/setup.sh"
export PATH="$HOME/.local/bin:$PATH"
git config --global --add safe.directory "$REPO_ROOT"
make -C "$REPO_ROOT" check
for profile in "${profiles[@]}"; do
  DOTFILES_PROFILE="$profile" make -C "$REPO_ROOT" integration
done
printf 'Native Ubuntu 26.04 checks passed for: %s\n' "${profiles[*]}"
