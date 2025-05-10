# dotfiles

Dotfiles for macOS

Rename the template `private_env.template` to `.private_env` and fill in your details

## Move config files

`mv ~/.zshrc ~/Documents/projects/dotfiles/.zshrc`<br>
`mv ~/.gitconfig ~/Documents/projects/dotfiles/.gitconfig`

## Create symlinks

```BASH
ln -s ~/Documents/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/Documents/projects/dotfiles/.gitconfig ~/.gitconfig
```

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
