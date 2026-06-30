
# Oh-My-Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Plugins
plugins=(git kubectl)
source $ZSH/oh-my-zsh.sh

# Shared configuration
. ~/.shrc

# Autocompletions
# uv: generate once, load from cache
_UV_COMP="$HOME/.zsh/completions/_uv"
if [[ ! -f "$_UV_COMP" ]]; then
    mkdir -p "$HOME/.zsh/completions"
    uv generate-shell-completion zsh > "$_UV_COMP"
fi
fpath=("$HOME/.zsh/completions" $fpath)
autoload -Uz compinit && compinit
unset _UV_COMP

[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# History Configuration
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_ALL_DUPS
setopt EXTENDED_HISTORY
HISTSIZE=10000
SAVEHIST=10000

# Additional Zsh Settings
ENABLE_CORRECTION="true"
COMPLETION_WAITING_DOTS="true"

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

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

# Syntax Highlighting & Autosuggestions
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
