#!/usr/bin/env bash

set -euo pipefail
PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_set="${DOTFILES_PACKAGE_SET:-workstation}"
case "$package_set" in
  workstation) package_file="$PLATFORM_DIR/apt-packages.txt" ;;
  homelab) package_file="$PLATFORM_DIR/apt-homelab-packages.txt" ;;
  *) printf 'Package set must be workstation or homelab.\n' >&2; exit 2 ;;
esac
packages=()
while IFS= read -r package; do
  [[ -n "$package" ]] || continue
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || { printf 'Invalid APT package name.\n' >&2; exit 1; }
  packages+=("$package")
done < "$package_file"
if [[ "${1:-}" == --dry-run ]]; then
  printf 'Would install native Ubuntu %s packages with APT: %s\n' "$package_set" "${packages[*]}"
  printf 'Would install checksum-pinned kubectl directly from dl.k8s.io.\n'
  if [[ "$package_set" == workstation ]]; then
    printf 'Would install missing/version-required pinned Linux tools and a Nerd Font from %s/tools.lock.json.\n' "$PLATFORM_DIR"
  fi
  exit 0
fi
[[ "$#" == 0 ]] || { printf 'Usage: bash platforms/ubuntu/setup.sh [--dry-run]\n' >&2; exit 2; }
command -v apt-get >/dev/null || { printf 'Ubuntu setup requires apt-get.\n' >&2; exit 1; }
elevated=()
if [[ "$EUID" != 0 ]]; then
  if ! command -v sudo >/dev/null || ! sudo -n true; then
    printf 'Run sudo -v in your own terminal, then rerun setup. No package changes were attempted.\n' >&2
    exit 1
  fi
  elevated=(sudo -n)
fi
"${elevated[@]}" apt-get update
"${elevated[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install --no-remove --no-upgrade --no-install-recommends -y "${packages[@]}"

export PATH="$HOME/.local/bin:$PATH"
tools_root="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/tools"
mkdir -p "$tools_root" "$HOME/.local/bin"
architecture="$(uname -m)"
case "$architecture" in x86_64|aarch64) ;; *) printf 'Unsupported Linux architecture: %s\n' "$architecture" >&2; exit 1 ;; esac

install_asset() {
  local name="$1" architecture_key="$2"
  local version record url checksum format destination staging
  version="$(jq -er --arg name "$name" '.assets[$name].version' "$PLATFORM_DIR/tools.lock.json")"
  record="$(jq -ec --arg name "$name" --arg architecture "$architecture_key" '.assets[$name][$architecture]' "$PLATFORM_DIR/tools.lock.json")"
  url="$(jq -er '.url' <<< "$record")"
  checksum="$(jq -er '.sha256' <<< "$record")"
  format="$(jq -er '.format' <<< "$record")"
  [[ "$url" == https://* && "$checksum" =~ ^[0-9a-f]{64}$ ]] || { printf 'Invalid upstream asset pin.\n' >&2; return 1; }
  destination="$tools_root/$name-$version-$architecture_key"
  if [[ ! -d "$destination" ]]; then
    staging="$(mktemp -d "$tools_root/.install-XXXXXX")"
    (
      trap 'rm -rf -- "$staging"' EXIT
      curl -fsSL --retry 3 "$url" -o "$staging/archive"
      ruby -rdigest -e 'abort "Asset checksum mismatch" unless Digest::SHA256.file(ARGV[0]).hexdigest == ARGV[1]' "$staging/archive" "$checksum"
      mkdir -p "$staging/unpacked"
      case "$format" in
        tar) tar -xzf "$staging/archive" -C "$staging/unpacked" ;;
        zip) unzip -q "$staging/archive" -d "$staging/unpacked" ;;
        binary) install -m 755 "$staging/archive" "$staging/unpacked/$name" ;;
        *) printf 'Unsupported asset archive.\n' >&2; exit 1 ;;
      esac
      mv "$staging/unpacked" "$destination"
    )
  fi
  if [[ "$name" == font ]]; then
    local font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/JetBrainsMonoNerdFont-$version"
    mkdir -p "$font_dir"
    find "$destination" -name '*.ttf' -exec cp -n {} "$font_dir/" \;
    fc-cache "$font_dir"
    return
  fi
  local records binary relative
  records="$(jq -r '.binaries | to_entries[] | [.key, .value] | @tsv' <<< "$record")"
  while IFS=$'\t' read -r binary relative; do
    [[ -f "$destination/$relative" ]] || { printf 'Pinned binary is missing: %s\n' "$binary" >&2; return 1; }
    chmod +x "$destination/$relative"
    if [[ -e "$HOME/.local/bin/$binary" || -L "$HOME/.local/bin/$binary" ]]; then
      [[ "$HOME/.local/bin/$binary" -ef "$destination/$relative" ]] || { printf 'Preserve or relocate the existing %s before installing this pin.\n' "$HOME/.local/bin/$binary" >&2; return 1; }
    else
      ln -s "$destination/$relative" "$HOME/.local/bin/$binary"
    fi
  done <<< "$records"
}

if ! nvim --headless -u NONE --noplugin -i NONE -n '+lua if vim.fn.has("nvim-0.11.3") == 0 then vim.cmd("cquit 1") end' +qa; then
  install_asset neovim "$architecture"
fi
install_asset kubectl "$architecture"
kubectl_version="$(jq -er '.assets.kubectl.version' "$PLATFORM_DIR/tools.lock.json")"
installed_kubectl_version="$("$HOME/.local/bin/kubectl" version --client --output=json | jq -er '.clientVersion.gitVersion')"
[[ "$installed_kubectl_version" == "v$kubectl_version" ]] || { printf 'kubectl does not match the declared Kubernetes release.\n' >&2; exit 1; }
if [[ "$package_set" == homelab ]]; then
  printf 'Lightweight Ubuntu homelab packages are ready.\n'
  exit 0
fi
if ! command -v stylua >/dev/null; then install_asset stylua "$architecture"; fi
if ! command -v oc >/dev/null; then install_asset openshift "$architecture"; fi
if ! yq --version 2>/dev/null | grep -q 'mikefarah/yq'; then install_asset yq "$architecture"; fi
if ! command -v prettier >/dev/null; then
  prettier_version="$(jq -er '.prettier' "$PLATFORM_DIR/tools.lock.json")"
  npm install --global --prefix "$HOME/.local" "prettier@$prettier_version"
fi
install_asset font all
printf 'Ubuntu packages and missing user-local tools are ready.\n'
