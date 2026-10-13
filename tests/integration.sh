#!/usr/bin/env bash

set -euo pipefail
umask 077

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/scripts/plugins.sh"
sandbox="$(mktemp -d /tmp/dotfiles-integration-XXXXXX)"
socket="$sandbox/tmux.sock"
cleanup() {
  tmux -S "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf -- "$sandbox"
}
trap cleanup EXIT

export HOME="$sandbox/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export DOTFILES_REPO="$REPO_ROOT"
export DOTFILES_SANDBOX="$sandbox"
export DOTFILES_PROFILE="${DOTFILES_PROFILE:-personal}"
export TMUX=""
unset ZDOTDIR ZSH_CUSTOM ZSH_CACHE_DIR NVIM_APPNAME KUBECONFIG
mkdir -p "$HOME"
install -m 600 "$REPO_ROOT/private_env.template" "$HOME/.private_env"

install_plugins "$REPO_ROOT/plugins.lock.json"
bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
zsh -dfi -c '
  source "$HOME/.zshenv"
  source "$HOME/.zshrc"
  [[ -n ${functions[compdef]-} ]] || exit 1
  [[ -r "$ZSH/oh-my-zsh.sh" ]] || exit 1
  if [[ "$DOTFILES_PROFILE" == work && $commands[oc] ]]; then
    [[ ${_comps[oc]-} == _oc && "$DOTFILES_OPENSHIFT_COMPLETION" == enabled ]] || exit 1
  else
    [[ "$DOTFILES_OPENSHIFT_COMPLETION" == disabled ]] || exit 1
  fi
  print "Pinned zsh startup passed for $DOTFILES_PLATFORM / $DOTFILES_PROFILE."
'
vim -Nu "$HOME/.vimrc" -i NONE -n -es -c 'qa!'
tmux -S "$socket" -f "$HOME/.tmux.conf" new-session -d -s dotfiles-integration
tmux -S "$socket" source-file -n "$HOME/.tmux.conf"
[[ "$(tmux -S "$socket" show-options -gqv prefix)" == C-s ]]
[[ -n "$(tmux -S "$socket" show-options -gqv @catppuccin_status_application)" ]]
printf 'Pinned Vim and tmux startup passed.\n'

nvim --headless -u NONE --noplugin -i NONE -n -l "$REPO_ROOT/tests/integration.lua"
printf 'All real pinned integration checks passed.\n'
