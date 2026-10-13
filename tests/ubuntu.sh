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
bash "$REPO_ROOT/platforms/ubuntu/setup.sh"
export PATH="$HOME/.local/bin:$PATH"
git config --global --add safe.directory "$REPO_ROOT"
make -C "$REPO_ROOT" check
for profile in "${profiles[@]}"; do
  DOTFILES_PROFILE="$profile" make -C "$REPO_ROOT" integration
done
printf 'Native Ubuntu 26.04 checks passed for: %s\n' "${profiles[*]}"
