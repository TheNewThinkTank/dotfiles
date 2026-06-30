# dotfiles

Dotfiles for macOS.
Includes config for zsh, tmux, nvim, git and more.

Rename the template `private_env.template` to `.private_env` and fill in your details

## Move config files

``` bash
mv ~/.zshrc ~/Documents/projects/dotfiles/.zshrc
mv ~/.gitconfig ~/Documents/projects/dotfiles/.gitconfig
```

## Create symlinks

``` bash
ln -s ~/Documents/projects/dotfiles/.shrc ~/.shrc
ln -s ~/Documents/projects/dotfiles/.bashrc ~/.bashrc
ln -s ~/Documents/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/Documents/projects/dotfiles/.gitconfig ~/.gitconfig
```

etc., or run rsync:

``` bash
rsync -av --delete ~/Documents/projects/dotfiles/.config/nvim/ ~/.config/nvim/
```

etc.

## Zsh config

- [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

## Vim config

```Bash
# Clone following repo to ~/.vim/bundle/Vundle.vim after making the parent dirs:
https://github.com/VundleVim/Vundle.vim

# Setup the config file as in this repo .vimrc example
# Install the Vundle plugins from `vim ~/.vimrc`, command mode, running: PluginInstall
```

## Neovim config

located in `.config/nvim`

## Homebrew

``` bash
# Create Brewfile
brew bundle dump --describe

# Update it when needed
brew bundle dump --force --describe

# Install brew packages
brew bundle --file ~/Documents/projects/dotfiles/Brewfile
```

TODO: move below section to separate document

## Git tips

``` bash
# Tell git to use it's built-in language parser for md files
echo '*.md diff=markdown' >> .gitattributes

# Search for changes to the README files' Usage section
git lg -L:Usage:README.md
```
