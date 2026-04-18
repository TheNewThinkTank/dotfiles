
# Oh-My-Zsh Configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"  #"powerlevel9k/powerlevel9k"  #"robbyrussell"

# Instant Prompt Setup (Powerlevel10k)

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Plugins

# plugins=(git kubectl-autocomplete)
plugins=(git kubectl)  # Oh-My-Zsh already includes kubectl plugin support with completions and useful aliases.
source $ZSH/oh-my-zsh.sh

# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(vcs dir rbenv)
# POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(root_indicator background_jobs status load)

# Autocompletions

# autoload -Uz compinit && compinit
eval "$(uv generate-shell-completion zsh)"
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)

# Aliases
alias k=kubectl
alias ls='colorls'
alias gh-create='gh repo create --private --source=. --remote=origin && git push -u --all && gh browse'

# History Configuration
HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%Y-%m-%d %T "

# NVM (Node Version Manager)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Additional Zsh Settings
ENABLE_CORRECTION="true"  # Enable command auto-correction
COMPLETION_WAITING_DOTS="true"  # Show dots while waiting for completion

# Custom Functions
function sshtmpl() {
  read "comment?Enter key comment (e.g., server name): "
  ssh-keygen -t ed25519 -C "$comment"
}

# # Powerlevel10k Configuration
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Syntax Highlighting & Autosuggestions
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh


# Begin blinking text mode
# I just use bold red here since my terminal has blinking disabled
export LESS_TERMCAP_mb=$'\e[1;31m'

# Begin bold text mode
export LESS_TERMCAP_md=$'\e[1;31m'

# End all special formatting started by mb/md/etc.
export LESS_TERMCAP_me=$'\e[0m'

# End standout mode
export LESS_TERMCAP_se=$'\e[0m'

# Begin standout mode
# search results - bold, yellow foreground, blue background.
export LESS_TERMCAP_so=$'\e[1;33;44m'

# End underline mode
export LESS_TERMCAP_ue=$'\e[0m'

# Begin underline mode
# underline and bold green
export LESS_TERMCAP_us=$'\e[4;1;32m'

# Begin reverse-video mode
export LESS_TERMCAP_mr=$'\e[7m'

# Begin dim/half-bright mode
export LESS_TERMCAP_mh=$'\e[2m'

# Begin subscript mode
# (probably isn't supported)
export LESS_TERMCAP_ZN=$'\e[74m'

# End subscript mode
# (probably isn't supported)
export LESS_TERMCAP_ZV=$'\e[75m'

# Begin superscript mode
# (probably isn't supported)
export LESS_TERMCAP_ZO=$'\e[73m'

# End superscript mode
# (probably isn't supported)
export LESS_TERMCAP_ZW=$'\e[75m'

# Finally wire up `man` to use `less`
# this is usually the default but let's just be sure
export MANPAGER='less'

