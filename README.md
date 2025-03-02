# dotfiles

dotfiles for Linux, Mac and Windows

Rename the template `private_env.template` to `.private_env` and fill in your details

<!--
## Move config files

`mv ~/.zshrc ~/Documents/projects/dotfiles/.zshrc`<br>
`mv ~/.gitconfig ~/Documents/projects/dotfiles/.gitconfig`
-->

```BASH
# Create symlinks
ln -s ~/Documents/projects/dotfiles/.zshrc ~/.zshrc
ln -s ~/Documents/projects/dotfiles/.gitconfig ~/.gitconfig
```

`brew bundle --file ~/Documents/projects/dotfiles/Brewfile`

## TODOs

- Add brewfile
