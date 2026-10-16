#!/usr/bin/env bash

clone_missing() {
  local repository="$1"
  local destination="$2"
  local entrypoint="$3"
  local revision="$4"
  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ ! -f "$destination/$entrypoint" ]]; then
      printf 'Incomplete plugin installation: %s\n' "$destination" >&2
      return 1
    fi
    return 0
  fi

  mkdir -p "${destination%/*}" || return
  local staging
  staging="$(mktemp -d "${destination%/*}/.dotfiles-plugin-XXXXXX")" || return
  (
    set -e
    trap 'rm -rf -- "$staging"' EXIT
    git clone --quiet --depth=1 "$repository" "$staging" || exit "$?"
    git -C "$staging" fetch --quiet --depth=1 origin "$revision" || exit "$?"
    git -C "$staging" checkout --quiet --detach FETCH_HEAD || exit "$?"
    installed_revision="$(git -C "$staging" rev-parse HEAD)" || exit "$?"
    if [[ "$installed_revision" != "$revision" || ! -f "$staging/$entrypoint" ]]; then
      printf 'Plugin revision or entrypoint verification failed: %s\n' "$repository" >&2
      exit 1
    fi
    if [[ -e "$destination" || -L "$destination" ]]; then
      printf 'Plugin destination appeared during installation: %s\n' "$destination" >&2
      exit 1
    fi
    mv "$staging" "$destination" || exit "$?"
  )
}

install_plugins() {
  local lockfile="$1"
  local operation="${2:-install}"
  case "$operation" in install|check) ;; *) printf 'Plugin operation must be install or check.\n' >&2; return 2 ;; esac
  command -v jq >/dev/null || return 1
  jq -e '
    .version == 1 and (.plugins | type == "array" and length > 0) and
    all(.plugins[];
      (.commit | test("^[0-9a-f]{40}$")) and
      (.repository | test("^https://github.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\\.git$")) and
      all([.destination, .entrypoint][];
        test("^[A-Za-z0-9_./-]+$") and (startswith("/") | not) and
        (split("/") | all(. != ".." and . != "." and . != "")))
    )
  ' "$lockfile" >/dev/null || return 1
  local records repository revision destination entrypoint
  records="$(jq -r '.plugins[] | [.repository, .commit, .destination, .entrypoint] | @tsv' "$lockfile")" || return
  while IFS=$'\t' read -r repository revision destination entrypoint; do
    if [[ "$operation" == check ]]; then
      [[ -e "$HOME/$destination" || -L "$HOME/$destination" ]] || return 3
      [[ -f "$HOME/$destination/$entrypoint" ]] || { printf 'Incomplete plugin installation: %s\n' "$destination" >&2; return 1; }
    else
      clone_missing "$repository" "$HOME/$destination" "$entrypoint" "$revision" || return
    fi
  done <<< "$records"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  [[ "$#" -ge 1 && "$#" -le 2 ]] || { printf 'Usage: bash scripts/plugins.sh LOCKFILE [install|check]\n' >&2; exit 2; }
  install_plugins "$1" "${2:-install}"
fi
