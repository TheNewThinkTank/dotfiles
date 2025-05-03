# export PATH="/usr/local/bin:$PATH"

# Path Configuration
typeset -U path PATH  # Ensure unique PATH entries

# Prepend preferred directories to PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.rd/bin:$PATH"
export PATH="/opt/homebrew/opt/sphinx-doc/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
# export PATH="/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH"
export PATH="/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"

# Environment Variables
export EDITOR=nvim
export LANG=en_US.UTF-8
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
export NVM_DIR="$HOME/.nvm"  # Required for NVM to function

# Source private environment variables (e.g., API keys)
[ -f "$HOME/Documents/projects/dotfiles/.private_env" ] && source "$HOME/Documents/projects/dotfiles/.private_env"

# Source Envman environment variables
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
