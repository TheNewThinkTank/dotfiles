# Path Configuration
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="/opt/homebrew/opt/sphinx-doc/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"

# Oh-My-Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins
plugins=(git kubectl-autocomplete)
source $ZSH/oh-my-zsh.sh

# Autocompletions
autoload -Uz compinit && compinit
eval "$(uv generate-shell-completion zsh)"
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# Aliases
alias k=kubectl

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
