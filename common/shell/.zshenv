# Path Configuration
typeset -U path PATH  # Ensure unique PATH entries

# Prepend preferred directories to PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
_CONTEXT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/environment.sh"
if [[ -r "$_CONTEXT_FILE" ]]; then
	source "$_CONTEXT_FILE" || return
fi
unset _CONTEXT_FILE

# Environment Variables
export EDITOR=nvim
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Source private environment variables (e.g., API keys)
if [[ -f "$HOME/.private_env" && -r "$HOME/.private_env" ]]; then
	source "$HOME/.private_env"
fi

# Source Envman environment variables
if [[ -s "${XDG_CONFIG_HOME:-$HOME/.config}/envman/load.sh" ]]; then
	source "${XDG_CONFIG_HOME:-$HOME/.config}/envman/load.sh"
fi
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local/environment.sh" ]]; then
	source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local/environment.sh"
fi
