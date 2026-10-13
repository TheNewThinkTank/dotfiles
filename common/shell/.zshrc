
_CONTEXT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/environment.sh"
if [[ -r "$_CONTEXT_FILE" ]]; then
  source "$_CONTEXT_FILE" || return
fi
unset _CONTEXT_FILE
if [[ -z "${DOTFILES_PROFILE:-}" ]]; then
  _PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile"
  if [[ -r "$_PROFILE_FILE" ]]; then
    DOTFILES_PROFILE="$(<"$_PROFILE_FILE")"
  else
    DOTFILES_PROFILE=personal
  fi
  unset _PROFILE_FILE
fi
case "$DOTFILES_PROFILE" in
  personal|work) export DOTFILES_PROFILE ;;
  *) print -u2 'Invalid DOTFILES_PROFILE: expected personal or work'; return 1 ;;
esac

# Oh-My-Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Plugins
plugins=(git kubectl)
_UV_COMP="$HOME/.zsh/completions/_uv"
if [[ $commands[uv] && ! -s "$_UV_COMP" ]]; then
  mkdir -p "$HOME/.zsh/completions"
  uv generate-shell-completion zsh > "$_UV_COMP" || true
fi
fpath=("$HOME/.zsh/completions" $fpath)
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi
if (( ! $+functions[compdef] )); then
  autoload -Uz compinit && compinit
fi
unset _UV_COMP

# Shared configuration
[[ ! -r "$HOME/.shrc" ]] || source "$HOME/.shrc"

# Autocompletions
DOTFILES_OPENSHIFT_COMPLETION=disabled
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)
if [[ "$DOTFILES_PROFILE" == work ]]; then
  _WORK_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profiles/work/shell.zsh"
  if [[ -r "$_WORK_FILE" ]]; then
    source "$_WORK_FILE"
  elif [[ $commands[oc] ]]; then
    source <(oc completion zsh)
    DOTFILES_OPENSHIFT_COMPLETION=enabled
  fi
  unset _WORK_FILE
fi

# History Configuration
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt EXTENDED_HISTORY
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=10000
SAVEHIST=10000

# NVM (Node Version Manager) — lazy-loaded to avoid shell startup cost
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  _load_nvm() {
    unfunction nvm node npm npx _load_nvm
    source "$NVM_DIR/nvm.sh"
    if [[ -s "$NVM_DIR/bash_completion" ]]; then
      source "$NVM_DIR/bash_completion"
    fi
  }
  nvm()  { _load_nvm && nvm "$@"; }
  node() { _load_nvm && node "$@"; }
  npm()  { _load_nvm && npm "$@"; }
  npx()  { _load_nvm && npx "$@"; }
fi

# Aliases
alias k=kubectl
alias gh-create='gh repo create --private --source=. --remote=origin && git push -u --all && gh browse'
sso-session() {
    local session="${1:?Usage: sso-session <session-name>}"
    aws sso login --sso-session "$session" --no-browser
}
alias awsconf="code ~/.aws/config"
alias awsls="aws configure list-profiles"
alias awswho="aws sts get-caller-identity"

# Custom Functions
function sshtmpl() {
  read "comment?Enter key comment (e.g., server name): "
  ssh-keygen -t ed25519 -C "$comment"
}

field () {
  awk -F "${2:- }" "{ print \$${1:-1} }"
}

total () {
  awk -F "${2:- }" "{ s += \$${1:-1} } END { print s}"
}

# Powerlevel10k Configuration
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local/shell.sh" ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local/shell.sh"
fi

# Syntax Highlighting & Autosuggestions
if [[ "${DOTFILES_PLATFORM:-macos}" == ubuntu ]]; then
  _BREW_PREFIX=/usr
else
  _BREW_PREFIX="${HOMEBREW_PREFIX:-}"
  if [[ -z "$_BREW_PREFIX" && $commands[brew] ]]; then
    _BREW_PREFIX="$(brew --prefix 2>/dev/null)" || _BREW_PREFIX=""
  fi
fi
if [[ -f "$_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [[ -f "$_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
unset _BREW_PREFIX
