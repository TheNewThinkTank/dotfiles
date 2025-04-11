# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path Configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="/opt/homebrew/opt/sphinx-doc/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
# Oh-My-Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"  #"powerlevel9k/powerlevel9k"  #"robbyrussell"

# Plugins
plugins=(git kubectl-autocomplete)
source $ZSH/oh-my-zsh.sh

# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(vcs dir rbenv)
# POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(root_indicator background_jobs status load)

# Autocompletions
autoload -Uz compinit && compinit
eval "$(uv generate-shell-completion zsh)"
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# Aliases
alias k=kubectl
alias ls='colorls'

alias gh-create='gh repo create --private --source=. --remote=origin && git push -u --all && gh browse'

# Editor Configuration
export EDITOR=vim

# Environment Variables
export LANG=en_US.UTF-8
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"

# History Configuration
HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%Y-%m-%d %T "

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Source private environment variables
[ -f "$HOME/Documents/projects/dotfiles/.private_env" ] && source "$HOME/Documents/projects/dotfiles/.private_env"

# Envman
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Additional Zsh Settings
ENABLE_CORRECTION="true"  # Enable command auto-correction
COMPLETION_WAITING_DOTS="true"  # Show dots while waiting for completion

function sshtmpl() {
  read "comment?Enter key comment (e.g., server name): "
  ssh-keygen -t ed25519 -C "$comment"
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

