# dotfiles

Dotfiles for macOS.
Includes config for zsh, tmux, nvim, git and more.

Rename the template `private_env.template` to `.private_env` and fill in your details.

## Bootstrap (fresh machine)

```bash
git clone https://github.com/TheNewThinkTank/dotfiles.git ~/Documents/projects/dotfiles
cd ~/Documents/projects/dotfiles
./bootstrap.sh
```

`bootstrap.sh` will:
1. Install Homebrew if not present
2. Install all packages from `Brewfile`
3. Sync dotfiles to `~`

## Move config files

```bash
mv ~/.zshrc ~/Documents/projects/dotfiles/.zshrc
mv ~/.gitconfig ~/Documents/projects/dotfiles/.gitconfig
```

## Create symlinks

```bash
ln -s ~/Documents/projects/dotfiles/.shrc ~/.shrc
ln -s ~/Documents/projects/dotfiles/.bashrc ~/.bashrc
ln -s ~/Documents/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/Documents/projects/dotfiles/.gitconfig ~/.gitconfig
```

Or run bootstrap.sh which uses rsync to sync all dotfiles at once.

## Zsh config

- [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

## Vim config

```bash
# Clone following repo to ~/.vim/bundle/Vundle.vim after making the parent dirs:
# https://github.com/VundleVim/Vundle.vim

# Setup the config file as in this repo .vimrc example
# Install the Vundle plugins from `vim ~/.vimrc`, command mode, running: PluginInstall
```

## Neovim config

Located in `nvim/.config/nvim/`.

## Homebrew

```bash
# Create Brewfile
brew bundle dump --describe

# Update it when needed
brew bundle dump --force --describe

# Install brew packages
brew bundle --file ~/Documents/projects/dotfiles/Brewfile
```

## Git tips

```bash
# Tell git to use its built-in language parser for md files
echo '*.md diff=markdown' >> .gitattributes

# Search for changes to the README files' Usage section
git lg -L:Usage:README.md
```
