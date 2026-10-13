#!/usr/bin/env bash

set -euo pipefail
umask 077

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/scripts/plugins.sh"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
ALL_ROOT_CONFIGS=(
  .aerospace.toml .bashrc .editorconfig .gitconfig .p10k.zsh
  .shrc .tmux.conf .vimrc .zshenv .zshrc
)
platform="${DOTFILES_PLATFORM:-}"
profile="${DOTFILES_PROFILE:-}"
force=false
dry_run=false
skip_install=false
update=false
restore_dir=""

usage() {
  printf 'Usage: %s [--profile personal|work] [--platform macos|ubuntu] [--force|-f] [--dry-run] [--skip-install] [--update] [--restore BACKUP]\n' "$0"
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

while [[ "$#" != 0 ]]; do
  case "$1" in
    --force|-f) force=true ;;
    --dry-run) dry_run=true ;;
    --skip-install) skip_install=true ;;
    --update) update=true ;;
    --profile|--platform)
      [[ "$#" -ge 2 && -n "$2" && "$2" != --* ]] || { usage >&2; exit 2; }
      if [[ "$1" == --profile ]]; then profile="$2"; else platform="$2"; fi
      shift
      ;;
    --restore)
      [[ "$#" -ge 2 && -n "$2" && "$2" != --* ]] || { usage >&2; exit 2; }
      restore_dir="$2"
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

[[ "$CONFIG_DIR" == /* && "$STATE_DIR" == /* ]] || die 'XDG directories must be absolute paths.'

if [[ -z "$profile" ]]; then
  if [[ -r "$CONFIG_DIR/dotfiles/profile" ]]; then
    profile="$(<"$CONFIG_DIR/dotfiles/profile")"
  else
    profile=personal
  fi
fi
case "$profile" in personal|work) ;; *) die 'Profile must be personal or work.' ;; esac
if [[ -z "$platform" ]]; then
  case "$(uname -s)" in
    Darwin) platform=macos ;;
    Linux)
      if [[ -r /etc/os-release ]] && (source /etc/os-release; [[ "$ID" == ubuntu ]]); then
        platform=ubuntu
      else
        die 'Unsupported Linux distribution; supported platforms are macos and ubuntu.'
      fi
      ;;
    *) die 'Supported platforms are macos and ubuntu.' ;;
  esac
fi
case "$platform" in macos|ubuntu) ;; *) die 'Platform must be macos or ubuntu.' ;; esac
export DOTFILES_PROFILE="$profile" DOTFILES_PLATFORM="$platform"
ROOT_CONFIGS=()
for config in "${ALL_ROOT_CONFIGS[@]}"; do
  [[ "$config" != .aerospace.toml || "$platform" == macos ]] || continue
  ROOT_CONFIGS+=("$config")
done

if [[ -n "$restore_dir" ]]; then
  if "$force" || "$update"; then
    die 'Restore requires explicit confirmation; --force and --update are deployment-only.'
  fi
  exec ruby "$DOTFILES_DIR/scripts/backups.rb" restore "$restore_dir" "$dry_run" "${ALL_ROOT_CONFIGS[@]}"
fi

if "$dry_run"; then
  printf 'Platform: %s; profile: %s\n' "$platform" "$profile"
  "$update" && printf 'Would update a clean checkout using git pull --ff-only.\n'
  if ! "$skip_install"; then
    bash "$DOTFILES_DIR/platforms/$platform/setup.sh" --dry-run
    printf 'Would install missing pinned shell, Vim, and tmux plugins.\n'
  fi
  printf 'Would back up replaced files under %s/dotfiles/backups/.\n' "$STATE_DIR"
  for config in "${ROOT_CONFIGS[@]}"; do
    printf '%s -> %s/%s\n' "$DOTFILES_DIR/$config" "$HOME" "$config"
  done
  printf '%s -> %s/nvim/\n' "$DOTFILES_DIR/nvim/.config/nvim/" "$CONFIG_DIR"
  printf '%s -> %s/ghostty/\n' "$DOTFILES_DIR/ghostty/.config/ghostty/" "$CONFIG_DIR"
  printf 'Would save profile and platform under %s/dotfiles/.\n' "$CONFIG_DIR"
  printf 'Would create a private environment file only if absent; no files would be deleted.\n'
  exit 0
fi

if ! "$force"; then
  printf 'Install dependencies and update managed configuration with backups? [y/N] '
  if ! read -r reply || [[ ! "$reply" =~ ^[Yy]$ ]]; then
    printf 'Cancelled.\n'
    exit 0
  fi
fi

if "$update"; then
  cd "$DOTFILES_DIR"
  git_state="$(git status --porcelain)"
  [[ -z "$git_state" ]] || die 'Commit or stash checkout changes before using --update.'
  git pull --ff-only origin main
fi

if ! "$skip_install"; then
  bash "$DOTFILES_DIR/platforms/$platform/setup.sh"
  if [[ "$platform" == macos ]]; then
    for candidate in "$(command -v brew || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$candidate" ]]; then eval "$("$candidate" shellenv)"; break; fi
    done
  else
    export PATH="$HOME/.local/bin:$PATH"
  fi
  install_plugins "$DOTFILES_DIR/plugins.lock.json"
fi

mkdir -p "$STATE_DIR/dotfiles/backups"
backup_dir="$(mktemp -d "$STATE_DIR/dotfiles/backups/$(date +%Y%m%d-%H%M%S)-XXXXXX")"
printf 'Backups: %s\n' "$backup_dir"
ruby "$DOTFILES_DIR/scripts/backups.rb" init "$backup_dir" "$DOTFILES_DIR" "${ROOT_CONFIGS[@]}"
finalize_backup() {
  local exit_code=$?
  trap - EXIT
  if ! ruby "$DOTFILES_DIR/scripts/backups.rb" finalize "$backup_dir" "$exit_code"; then
    printf 'Backup manifest could not be finalized: %s\n' "$backup_dir" >&2
    [[ "$exit_code" != 0 ]] || exit_code=1
  fi
  exit "$exit_code"
}
trap finalize_backup EXIT
mkdir -p "$CONFIG_DIR/nvim" "$CONFIG_DIR/ghostty" \
  "$HOME/.vim/backup" "$HOME/.vim/swaps" "$HOME/.vim/undo"

sync_config() {
  local source_path="$1"
  local destination="$2"
  local backup_path="$3"
  if [[ "$source_path" -ef "$destination" ]]; then
    return 0
  fi
  rsync -av --copy-links --no-perms --backup --backup-dir="$backup_path" "$source_path" "$destination"
}

for config in "${ROOT_CONFIGS[@]}"; do
  sync_config "$DOTFILES_DIR/$config" "$HOME/$config" "$backup_dir/home"
done
sync_config "$DOTFILES_DIR/nvim/.config/nvim/" "$CONFIG_DIR/nvim/" "$backup_dir/config/nvim"
sync_config "$DOTFILES_DIR/ghostty/.config/ghostty/" "$CONFIG_DIR/ghostty/" "$backup_dir/config/ghostty"
selector_staging="$(mktemp -d "$backup_dir/.selectors-XXXXXX")"
printf '%s\n' "$profile" > "$selector_staging/profile"
printf '%s\n' "$platform" > "$selector_staging/platform"
cp "$DOTFILES_DIR/common/shell/environment.sh" "$selector_staging/environment.sh"
mkdir -p "$selector_staging/platform.d" "$selector_staging/profiles/work"
cp "$DOTFILES_DIR/platforms/$platform/shell.sh" "$selector_staging/platform.d/shell.sh"
cp "$DOTFILES_DIR/platforms/$platform/ghostty.conf" "$selector_staging/platform.d/ghostty.conf"
cp "$DOTFILES_DIR/profiles/work/shell.zsh" "$selector_staging/profiles/work/shell.zsh"
mkdir -p "$CONFIG_DIR/dotfiles"
sync_config "$selector_staging/" "$CONFIG_DIR/dotfiles/" "$backup_dir/config/dotfiles"
rm -rf -- "$selector_staging"

if [[ ! -e "$HOME/.private_env" && ! -L "$HOME/.private_env" ]]; then
  private_source="$DOTFILES_DIR/private_env.template"
  if [[ -f "$DOTFILES_DIR/.private_env" ]]; then
    private_source="$DOTFILES_DIR/.private_env"
  fi
  install -m 600 "$private_source" "$HOME/.private_env"
fi
if [[ -f "$HOME/.private_env" ]]; then
  chmod 600 "$HOME/.private_env"
fi
printf 'Configuration installed. Open a new terminal to load it.\n'
