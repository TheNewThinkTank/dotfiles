
# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

shopt -s extglob

# Can be non-ideal, e.g. when running ls on an empty dir,
# ls will run on the current dir instead
shopt -s nullglob
# ex: printf '<%s>\n' empty/*

# Show hidden files
shopt -s dotglob
# ex: echo empty/*

# for recursion
shopt -s globstar
# ex: printf '%s\n' **
# ex: txt=( ./**/*.txt ); echo "${#txt[@]}"

