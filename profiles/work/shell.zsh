if command -v oc >/dev/null; then
  source <(oc completion zsh)
  DOTFILES_OPENSHIFT_COMPLETION=enabled
fi
