# dotfiles

Dotfiles for macOS.
Includes config for zsh, tmux, nvim, git and more.

Rename the template `private_env.template` to `.private_env` and fill in your details

## Move config files

`mv ~/.zshrc ~/Documents/projects/dotfiles/.zshrc`<br>
`mv ~/.gitconfig ~/Documents/projects/dotfiles/.gitconfig`

## Create symlinks

```BASH
ln -s ~/Documents/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/Documents/projects/dotfiles/.gitconfig ~/.gitconfig
```

## Zsh config

- [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

## Homebrew

```BASH
# Create Brewfile
brew bundle dump --describe

# Update it when needed
brew bundle dump --force --describe

# Test that Brewfile works by simulating an install
brew bundle install --dry-run

# Install brew packages
brew bundle --file ~/Documents/projects/dotfiles/Brewfile
```

TODO: move below section to separate document

## Git tips

```BASH
# Tell git to use it's built-in language parser for md files
echo '*.md diff=markdown' >> .gitattributes

# Search for changes to the README files' Usage section
git lg -L:Usage:README.md
```
