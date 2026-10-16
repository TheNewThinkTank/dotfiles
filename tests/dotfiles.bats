#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REAL_GIT="$(command -v git)"
  REAL_ZSH="$(command -v zsh)"
  REAL_BASH="$(command -v bash)"
  REAL_NVIM="$(command -v nvim)"
  REAL_TMUX="$(command -v tmux)"
  REAL_VIM="$(command -v vim)"
  REAL_RSYNC="$(command -v rsync)"
  export REAL_RSYNC
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_STATE_HOME="$HOME/.local/state"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  export MOCK_LOG="$BATS_TEST_TMPDIR/installer-calls"
  unset MOCK_BREW_EXIT MOCK_GIT_DIRTY MOCK_GIT_EXIT MOCK_PARTIAL_CLONE MOCK_PIN_MISMATCH MOCK_BREW_INFO MOCK_BREW_INFO_EXIT DOTFILES_PROFILE DOTFILES_PLATFORM DOTFILES_PACKAGE_SET
  export DOTFILES_PLATFORM=macos
  mkdir -p "$HOME/bin"
  export PATH="$HOME/bin:$PATH"
  cat > "$HOME/bin/brew" <<'MOCK'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >> "$MOCK_LOG"
case "$1" in
  shellenv) printf 'export HOMEBREW_PREFIX="%s"\n' "$HOME/homebrew" ;;
  --prefix) printf '%s\n' "$HOME/homebrew" ;;
  bundle) exit "${MOCK_BREW_EXIT:-0}" ;;
  info)
    [[ "${MOCK_BREW_INFO_EXIT:-0}" == 0 ]] || exit "$MOCK_BREW_INFO_EXIT"
    cat "$MOCK_BREW_INFO"
    ;;
esac
MOCK
  cat > "$HOME/bin/git" <<'MOCK'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "$MOCK_LOG"
case "$1" in
  status) printf '%s' "${MOCK_GIT_DIRTY:-}" ;;
  pull) exit "${MOCK_GIT_EXIT:-0}" ;;
  -C)
    directory="$2"
    shift 2
    case "$1" in
      fetch) printf '%s\n' "${@: -1}" > "$directory/.mock-revision" ;;
      rev-parse)
        if [[ "${MOCK_PIN_MISMATCH:-0}" == 1 ]]; then
          printf '%040d\n' 0
        else
          cat "$directory/.mock-revision"
        fi
        ;;
    esac
    ;;
  clone)
    destination="${@: -1}"
    if [[ "${MOCK_PARTIAL_CLONE:-0}" == 1 ]]; then
      mkdir -p "$destination/.git"
      touch "$destination/partial-download"
      exit 41
    fi
    [[ "${MOCK_GIT_EXIT:-0}" == 0 ]] || exit "$MOCK_GIT_EXIT"
    mkdir -p "$destination/autoload"
    case "$*" in
      *ohmyzsh*) touch "$destination/oh-my-zsh.sh" ;;
      *powerlevel10k*) touch "$destination/powerlevel10k.zsh-theme" ;;
      *Vundle*) touch "$destination/autoload/vundle.vim" ;;
      *tpm.git*) touch "$destination/tpm" ;;
      *catppuccin/tmux.git*) touch "$destination/catppuccin.tmux" ;;
      *tmux-cpu*) touch "$destination/cpu.tmux" ;;
      *tmux-battery*) touch "$destination/battery.tmux" ;;
    esac
    ;;
esac
MOCK
  chmod +x "$HOME/bin/brew" "$HOME/bin/git"
}

teardown() {
  if [[ -n "${TMUX_SOCKET:-}" ]]; then
    "$REAL_TMUX" -S "$TMUX_SOCKET" kill-server >/dev/null 2>&1 || true
  fi
}

prepare_homelab_asset_test() {
  ASSET_PLATFORM="$BATS_TEST_TMPDIR/platform"
  export MOCK_KUBECTL="$BATS_TEST_TMPDIR/kubectl-fixture"
  mkdir -p "$ASSET_PLATFORM"
  cp "$REPO_ROOT/platforms/ubuntu/setup.sh" "$REPO_ROOT/platforms/ubuntu/apt-homelab-packages.txt" "$ASSET_PLATFORM/"
  cat > "$MOCK_KUBECTL" <<'MOCK'
#!/usr/bin/env bash
printf '{"clientVersion":{"gitVersion":"v1.37.1"}}\n'
MOCK
  checksum="$(ruby -rdigest -e 'puts Digest::SHA256.file(ARGV[0]).hexdigest' "$MOCK_KUBECTL")"
  jq --arg checksum "$checksum" '
    .assets.kubectl.x86_64.sha256 = $checksum |
    .assets.kubectl.aarch64.sha256 = $checksum
  ' "$REPO_ROOT/platforms/ubuntu/tools.lock.json" > "$ASSET_PLATFORM/tools.lock.json"
  cat > "$HOME/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$MOCK_LOG"
while [[ "$#" != 0 ]]; do
  if [[ "$1" == -o ]]; then cp "$MOCK_KUBECTL" "$2"; exit; fi
  shift
done
exit 2
MOCK
  cat > "$HOME/bin/apt-get" <<'MOCK'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >> "$MOCK_LOG"
MOCK
  cat > "$HOME/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
shift
exec "$@"
MOCK
  cat > "$HOME/bin/nvim" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
  cat > "$HOME/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_LINUX_ARCH:-x86_64}"
MOCK
  chmod +x "$HOME/bin/curl" "$HOME/bin/apt-get" "$HOME/bin/sudo" "$HOME/bin/nvim" "$HOME/bin/uname"
}

@test "bootstrap dry-run has no installer or filesystem side effects" {
  before="$(find "$HOME" -print | sort)"
  run bash "$REPO_ROOT/bootstrap.sh" --dry-run
  [[ "$status" == 0 ]]
  [[ "$output" == *"$XDG_CONFIG_HOME/nvim/"* ]]
  [[ "$output" == *"$XDG_CONFIG_HOME/ghostty/"* ]]
  [[ ! -e "$MOCK_LOG" ]]
  [[ "$(find "$HOME" -print | sort)" == "$before" ]]
}

@test "configuration check is read-only and repeated deployment converges" {
  before="$(find "$HOME" -print | sort)"
  run bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile personal
  [[ "$status" == 3 ]]
  [[ "$(find "$HOME" -print | sort)" == "$before" ]]
  [[ ! -e "$MOCK_LOG" ]]

  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  backup_count="${#backups[@]}"
  run bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal
  [[ "$status" == 0 && "$output" == *'Configuration unchanged'* ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  [[ "${#backups[@]}" == "$backup_count" ]]

  printf 'local drift\n' > "$HOME/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile personal
  [[ "$status" == 3 ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
}

@test "deployment repairs same-size content drift with preserved timestamps" {
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
  ruby -e 'file = ARGV.fetch(0); content = File.binread(file); content.setbyte(0, 65); File.binwrite(file, content)' "$HOME/.zshrc"
  touch -r "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile personal
  [[ "$status" == 3 ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
}

@test "plugin check is read-only and converges after installation" {
  before="$(find "$HOME" -print | sort)"
  run bash "$REPO_ROOT/scripts/plugins.sh" "$REPO_ROOT/plugins.lock.json" check
  [[ "$status" == 3 && ! -e "$MOCK_LOG" ]]
  [[ "$(find "$HOME" -print | sort)" == "$before" ]]
  run bash "$REPO_ROOT/scripts/plugins.sh" "$REPO_ROOT/plugins.lock.json" install
  [[ "$status" == 0 ]]
  calls="$(wc -l < "$MOCK_LOG")"
  run bash "$REPO_ROOT/scripts/plugins.sh" "$REPO_ROOT/plugins.lock.json" check
  [[ "$status" == 0 && "$(wc -l < "$MOCK_LOG")" == "$calls" ]]
}

@test "bootstrap rejects unknown arguments without installing" {
  run bash "$REPO_ROOT/bootstrap.sh" --unknown
  [[ "$status" == 2 ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "bootstrap validates selectors without invoking installers" {
  run bash "$REPO_ROOT/bootstrap.sh" --dry-run --profile unknown
  [[ "$status" == 1 && "$output" == *'Profile must be'* ]]
  run bash "$REPO_ROOT/bootstrap.sh" --dry-run --platform windows
  [[ "$status" == 1 && "$output" == *'Platform must be'* ]]
  run bash "$REPO_ROOT/bootstrap.sh" --profile
  [[ "$status" == 2 ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "bootstrap previews all platform and profile combinations without changes" {
  for platform in macos ubuntu; do
    for profile in personal work; do
      run bash "$REPO_ROOT/bootstrap.sh" --dry-run --platform "$platform" --profile "$profile"
      [[ "$status" == 0 && "$output" == *"Platform: $platform; profile: $profile"* ]]
      if [[ "$platform" == ubuntu ]]; then [[ "$output" != *'.aerospace.toml'* ]]; fi
    done
  done
  [[ ! -e "$MOCK_LOG" && ! -e "$XDG_CONFIG_HOME/dotfiles" ]]
}

@test "Ubuntu installer preview uses native packages and verified asset pins" {
  run bash "$REPO_ROOT/platforms/ubuntu/setup.sh" --dry-run
  [[ "$status" == 0 && "$output" == *'with APT'* && "$output" == *wl-clipboard* ]]
  [[ "$output" != *Homebrew* ]]
  run jq -e '.version == 1 and all(.assets[]; all(to_entries[] | select(.key != "version"); (.value.sha256 | test("^[0-9a-f]{64}$")) and (.value.url | startswith("https://"))))' "$REPO_ROOT/platforms/ubuntu/tools.lock.json"
  [[ "$status" == 0 ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "homelab package selection is lightweight Ubuntu-only and saved" {
  run bash "$REPO_ROOT/bootstrap.sh" --dry-run --platform ubuntu --profile personal --package-set homelab
  [[ "$status" == 0 && "$output" == *'Package set: homelab'* ]]
  [[ "$output" == *'tmux'* && "$output" != *'ghostty fontconfig'* ]]
  run env DOTFILES_PACKAGE_SET=homelab bash "$REPO_ROOT/platforms/ubuntu/setup.sh" --dry-run
  [[ "$status" == 0 && "$output" != *wl-clipboard* && "$output" != *build-essential* ]]
  run bash "$REPO_ROOT/bootstrap.sh" --platform macos --package-set homelab --dry-run
  [[ "$status" == 1 && "$output" == *'Ubuntu-only'* ]]
  [[ ! -e "$MOCK_LOG" ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu --profile personal --package-set homelab
  [[ "$status" == 0 ]]
  grep -qx homelab "$XDG_CONFIG_HOME/dotfiles/package-set"
  run bash "$REPO_ROOT/bootstrap.sh" --check --platform ubuntu --profile personal
  [[ "$status" == 0 ]]
}

@test "MacBook manifest includes homelab controller tools and maintained manual pages" {
  for package in actionlint gitleaks helm@3 kubernetes-cli tlrc; do
    grep -qx "brew \"$package\"" "$REPO_ROOT/platforms/macos/Brewfile"
  done
  run grep -qx 'brew "tldr"' "$REPO_ROOT/platforms/macos/Brewfile"
  [[ "$status" == 1 ]]
}

@test "kubectl is pinned to Kubernetes and never installed from OpenShift" {
  run jq -e '
    .assets.kubectl.version == "1.37.1" and
    (.assets.kubectl.x86_64.url | startswith("https://dl.k8s.io/")) and
    (.assets.kubectl.aarch64.url | startswith("https://dl.k8s.io/")) and
    (.assets.openshift.x86_64.binaries | has("kubectl") | not) and
    (.assets.openshift.aarch64.binaries | has("kubectl") | not)
  ' "$REPO_ROOT/platforms/ubuntu/tools.lock.json"
  [[ "$status" == 0 ]]
}

@test "homelab installer verifies official kubectl once and does not install OpenShift" {
  prepare_homelab_asset_test
  run env DOTFILES_PACKAGE_SET=homelab bash "$ASSET_PLATFORM/setup.sh"
  [[ "$status" == 0 && -x "$HOME/.local/bin/kubectl" ]]
  grep -q 'https://dl.k8s.io/' "$MOCK_LOG"
  [[ "$(grep -c '^curl ' "$MOCK_LOG")" == 1 ]]
  run env DOTFILES_PACKAGE_SET=homelab bash "$ASSET_PLATFORM/setup.sh"
  [[ "$status" == 0 ]]
  [[ "$(grep -c '^curl ' "$MOCK_LOG")" == 1 ]]
  run grep -E 'openshift|fc-cache|npm install' "$MOCK_LOG"
  [[ "$status" == 1 ]]
}

@test "kubectl checksum failure never publishes a binary or leaves staging" {
  prepare_homelab_asset_test
  printf 'tampered fixture\n' >> "$MOCK_KUBECTL"
  run env DOTFILES_PACKAGE_SET=homelab bash "$ASSET_PLATFORM/setup.sh"
  [[ "$status" == 1 && "$output" == *'checksum mismatch'* ]]
  [[ ! -e "$HOME/.local/bin/kubectl" && ! -L "$HOME/.local/bin/kubectl" ]]
  [[ -z "$(find "$XDG_DATA_HOME/dotfiles/tools" -name '.install-*' -print)" ]]
}

@test "kubectl installation preserves an existing user-local binary" {
  prepare_homelab_asset_test
  mkdir -p "$HOME/.local/bin"
  printf 'preserve existing client\n' > "$HOME/.local/bin/kubectl"
  run env DOTFILES_PACKAGE_SET=homelab bash "$ASSET_PLATFORM/setup.sh"
  [[ "$status" == 1 && "$output" == *'Preserve or relocate'* ]]
  grep -qx 'preserve existing client' "$HOME/.local/bin/kubectl"
}

@test "Ubuntu package mappings provision formatter executables not only libraries" {
  grep -qx isort "$REPO_ROOT/platforms/ubuntu/apt-packages.txt"
  grep -qx rubocop "$REPO_ROOT/platforms/ubuntu/apt-packages.txt"
}

@test "Ubuntu APT failures stop before tool downloads or config deployment" {
  cat > "$HOME/bin/apt-get" <<'MOCK'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*" >> "$MOCK_LOG"
exit 57
MOCK
  cat > "$HOME/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
shift
exec "$@"
MOCK
  chmod +x "$HOME/bin/apt-get" "$HOME/bin/sudo"
  run bash "$REPO_ROOT/bootstrap.sh" --force --platform ubuntu
  [[ "$status" == 57 && ! -e "$HOME/.zshrc" ]]
  run grep -q 'git clone' "$MOCK_LOG"
  [[ "$status" == 1 ]]
}

@test "bootstrap saves profile selectors and records them in backup manifests" {
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --profile work --platform ubuntu
  [[ "$status" == 0 ]]
  grep -qx work "$XDG_CONFIG_HOME/dotfiles/profile"
  grep -qx ubuntu "$XDG_CONFIG_HOME/dotfiles/platform"
  [[ ! -e "$HOME/.aerospace.toml" ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  run jq -e '.selectors.platform == "ubuntu" and .selectors.profile == "work"' "${backups[0]}/manifest.json"
  [[ "$status" == 0 ]]
  run bash "$REPO_ROOT/bootstrap.sh" --dry-run
  [[ "$status" == 0 && "$output" == *'profile: work'* ]]
}

@test "backup restoration recovers saved personal selection after a work deployment" {
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform macos --profile personal
  [[ "$status" == 0 ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform macos --profile work
  [[ "$status" == 0 ]]
  work_backup=""
  for manifest in "$XDG_STATE_HOME"/dotfiles/backups/*/manifest.json; do
    if [[ "$(jq -r '.selectors.profile' "$manifest")" == work ]]; then work_backup="${manifest%/manifest.json}"; fi
  done
  [[ -n "$work_backup" ]]
  run bash -c 'printf "restore\n" | bash "$1/bootstrap.sh" --restore "$2"' dotfiles-test "$REPO_ROOT" "$work_backup"
  [[ "$status" == 0 ]]
  grep -qx personal "$XDG_CONFIG_HOME/dotfiles/profile"
  [[ -f "$HOME/.private_env" ]]
}

@test "CI covers macOS and Ubuntu 26.04 with both profiles" {
  run yq -o=json "$REPO_ROOT/.github/workflows/ci.yml"
  [[ "$status" == 0 ]]
  run jq -e '
    .jobs.macos."runs-on" == "macos-latest" and .jobs.ubuntu.container == "ubuntu:26.04" and
    .jobs.macos.strategy.matrix.profile == ["personal", "work"] and
    .jobs.ubuntu.strategy.matrix.profile == ["personal", "work"] and
    .jobs["ubuntu-homelab"].env.DOTFILES_PACKAGE_SET == "homelab" and
    .jobs["ubuntu-homelab"].strategy.matrix.profile == ["personal", "work"]
  ' <<< "$output"
  [[ "$status" == 0 ]]
}

@test "bootstrap confirms before running installers" {
  run bash -c 'printf "n\n" | bash "$1"' dotfiles-test "$REPO_ROOT/bootstrap.sh"
  [[ "$status" == 0 ]]
  [[ "$output" == *Cancelled* ]]
  [[ ! -e "$MOCK_LOG" ]]
  [[ ! -e "$HOME/.zshrc" ]]
}

@test "bootstrap deploys application configs to XDG directories only" {
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  cmp "$REPO_ROOT/nvim/.config/nvim/init.lua" "$XDG_CONFIG_HOME/nvim/init.lua"
  cmp "$REPO_ROOT/ghostty/.config/ghostty/config" "$XDG_CONFIG_HOME/ghostty/config"
  [[ ! -e "$HOME/nvim" && ! -e "$HOME/ghostty" ]]
  [[ ! -e "$HOME/Brewfile" && ! -e "$HOME/.gitignore" && ! -e "$HOME/tests" ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "bootstrap backs up replaced files and preserves unrelated files" {
  printf 'old shell configuration\n' > "$HOME/.zshrc"
  mkdir -p "$XDG_CONFIG_HOME/nvim"
  printf 'old editor configuration\n' > "$XDG_CONFIG_HOME/nvim/init.lua"
  printf 'keep this\n' > "$XDG_CONFIG_HOME/nvim/custom.txt"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  grep -qx 'old shell configuration' "${backups[0]}/home/.zshrc"
  grep -qx 'old editor configuration' "${backups[0]}/config/nvim/init.lua"
  grep -qx 'keep this' "$XDG_CONFIG_HOME/nvim/custom.txt"
}

@test "backup manifests record checksums destinations and completion" {
  printf 'old shell configuration\n' > "$HOME/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  manifest="${backups[0]}/manifest.json"
  [[ "$(ls -l "$manifest")" == -rw-------* ]]
  run jq -e --arg home "$HOME" '
    .version == 1 and .status == "complete" and .exit_code == 0 and
    .roots.home == $home and
    any(.entries[]; .backup == "home/.zshrc" and .destination == ($home + "/.zshrc") and (.sha256 | length == 64))
  ' "$manifest"
  [[ "$status" == 0 ]]
}

@test "failed deployments still finalize backups of already replaced files" {
  printf 'old window manager configuration\n' > "$HOME/.aerospace.toml"
  cat > "$HOME/bin/rsync" <<'MOCK'
#!/usr/bin/env bash
if [[ "${@: -1}" == */.bashrc ]]; then exit 23; fi
exec "$REAL_RSYNC" "$@"
MOCK
  chmod +x "$HOME/bin/rsync"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 23 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  run jq -e '.status == "failed" and .exit_code == 23 and any(.entries[]; .backup == "home/.aerospace.toml")' "${backups[0]}/manifest.json"
  [[ "$status" == 0 ]]
}

make_restore_fixture() {
  printf 'original shell configuration\n' > "$HOME/.zshrc"
  mkdir -p "$XDG_CONFIG_HOME/nvim"
  printf 'original editor configuration\n' > "$XDG_CONFIG_HOME/nvim/init.lua"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  RESTORE_BACKUP="${backups[0]}"
}

@test "restore preview does not change files or create another backup" {
  make_restore_fixture
  before="$(find "$HOME" -print | sort)"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 0 && "$output" == *'Restore home/.zshrc'* ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
  [[ "$(find "$HOME" -print | sort)" == "$before" ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "restore cancels unless the exact confirmation is provided" {
  make_restore_fixture
  run bash -c 'printf "yes\n" | bash "$1/bootstrap.sh" --restore "$2"' \
    dotfiles-test "$REPO_ROOT" "$RESTORE_BACKUP"
  [[ "$status" == 0 && "$output" == *Cancelled* ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --force
  [[ "$status" == 1 && "$output" == *'explicit confirmation'* ]]
}

@test "confirmed restores recover saved files and back up current versions" {
  make_restore_fixture
  printf 'current shell changes\n' > "$HOME/.zshrc"
  printf 'current editor changes\n' > "$XDG_CONFIG_HOME/nvim/init.lua"
  printf 'unrelated file\n' > "$XDG_CONFIG_HOME/nvim/unrelated.txt"
  run bash -c 'printf "restore\n" | bash "$1/bootstrap.sh" --restore "$2"' \
    dotfiles-test "$REPO_ROOT" "$RESTORE_BACKUP"
  [[ "$status" == 0 ]]
  grep -qx 'original shell configuration' "$HOME/.zshrc"
  grep -qx 'original editor configuration' "$XDG_CONFIG_HOME/nvim/init.lua"
  grep -qx 'unrelated file' "$XDG_CONFIG_HOME/nvim/unrelated.txt"
  rollback=("$XDG_STATE_HOME"/dotfiles/backups/restore-*)
  grep -qx 'current shell changes' "${rollback[0]}/home/.zshrc"
  grep -qx 'current editor changes' "${rollback[0]}/config/nvim/init.lua"
  run jq -e '.status == "complete" and .action == "restore"' "${rollback[0]}/manifest.json"
  [[ "$status" == 0 ]]
  [[ -f "$HOME/.private_env" && -f "$HOME/.bashrc" ]]
}

@test "restore refuses modified backup payloads before confirmation" {
  make_restore_fixture
  printf 'tampered\n' >> "$RESTORE_BACKUP/home/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 1 && "$output" == *'checksum or permissions'* ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
}

@test "restore refuses path traversal and mismatched destinations" {
  make_restore_fixture
  cp "$RESTORE_BACKUP/manifest.json" "$BATS_TEST_TMPDIR/original-manifest.json"
  jq '.entries[0].backup = "../outside"' "$BATS_TEST_TMPDIR/original-manifest.json" > "$RESTORE_BACKUP/manifest.json"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 1 && "$output" == *'Invalid backup path'* ]]
  jq '.entries[0].destination = "/outside"' "$BATS_TEST_TMPDIR/original-manifest.json" > "$RESTORE_BACKUP/manifest.json"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 1 && "$output" == *'recorded path'* ]]
  cmp "$REPO_ROOT/.zshrc" "$HOME/.zshrc"
}

@test "restore rejects changed home or config roots" {
  make_restore_fixture
  run env XDG_CONFIG_HOME="$HOME/other-config" bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 1 && "$output" == *'different home or config roots'* ]]
}

@test "restore refuses application-directory symlink escapes" {
  make_restore_fixture
  mv "$XDG_CONFIG_HOME/nvim" "$HOME/previous-nvim"
  mkdir -p "$HOME/outside-config"
  printf 'do not change\n' > "$HOME/outside-config/init.lua"
  ln -s "$HOME/outside-config" "$XDG_CONFIG_HOME/nvim"
  run bash "$REPO_ROOT/bootstrap.sh" --restore "$RESTORE_BACKUP" --dry-run
  [[ "$status" == 1 && "$output" == *'symlink boundary'* ]]
  grep -qx 'do not change' "$HOME/outside-config/init.lua"
}

@test "restore preserves original file symlinks" {
  printf 'linked shell configuration\n' > "$HOME/original-shell"
  ln -s "$HOME/original-shell" "$HOME/.zshrc"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  backups=("$XDG_STATE_HOME"/dotfiles/backups/*)
  run bash -c 'printf "restore\n" | bash "$1/bootstrap.sh" --restore "$2"' \
    dotfiles-test "$REPO_ROOT" "${backups[0]}"
  [[ "$status" == 0 && -L "$HOME/.zshrc" ]]
  [[ "$(readlink "$HOME/.zshrc")" == "$HOME/original-shell" ]]
}

@test "restore revalidates destinations after waiting for confirmation" {
  make_restore_fixture
  mkdir -p "$HOME/outside-config"
  printf 'do not change\n' > "$HOME/outside-config/init.lua"
  run ruby -ropen3 -rtimeout -e '
    Open3.popen3("bash", ARGV[0], "--restore", ARGV[1]) do |input, output, errors, process|
      begin
        Timeout.timeout(10) do
          transcript = ""
          until transcript.include?("rollback backups: ")
            character = output.read(1)
            abort "Restore exited before confirmation" unless character
            transcript << character
          end
          File.rename(ARGV[2], ARGV[3])
          File.symlink(ARGV[4], ARGV[2])
          input.puts("restore")
          input.close
          output.read
          diagnostics = errors.read
          abort "Changed destination was accepted" if process.value.success?
          abort diagnostics unless diagnostics.include?("symlink boundary")
        end
      ensure
        Process.kill("TERM", process.pid) if process.alive?
      end
    end
  ' "$REPO_ROOT/bootstrap.sh" "$RESTORE_BACKUP" "$XDG_CONFIG_HOME/nvim" "$HOME/previous-nvim" "$HOME/outside-config"
  [[ "$status" == 0 ]]
  grep -qx 'do not change' "$HOME/outside-config/init.lua"
}

@test "bootstrap preserves links to the checkout" {
  ln -s "$REPO_ROOT/.shrc" "$HOME/.shrc"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  [[ -L "$HOME/.shrc" ]]
  [[ "$(readlink "$HOME/.shrc")" == "$REPO_ROOT/.shrc" ]]
}

@test "bootstrap creates private credentials and Vim state directories" {
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  [[ -f "$HOME/.private_env" ]]
  [[ "$(ls -l "$HOME/.private_env")" == -rw-------* ]]
  [[ -d "$HOME/.vim/backup" && -d "$HOME/.vim/swaps" && -d "$HOME/.vim/undo" ]]
}

@test "bootstrap never overwrites existing private credentials" {
  printf 'export DOTFILES_TEST_CREDENTIAL=fixture\n' > "$HOME/.private_env"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install
  [[ "$status" == 0 ]]
  grep -qx 'export DOTFILES_TEST_CREDENTIAL=fixture' "$HOME/.private_env"
  [[ "$(ls -l "$HOME/.private_env")" == -rw-------* ]]
}

@test "bootstrap stops before deployment when brew fails" {
  run env MOCK_BREW_EXIT=47 bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 47 ]]
  [[ ! -e "$HOME/.zshrc" && ! -e "$XDG_STATE_HOME/dotfiles" ]]
  run grep -q 'git clone' "$MOCK_LOG"
  [[ "$status" == 1 ]]
}

@test "bootstrap stops before deployment when a plugin clone fails" {
  run env MOCK_GIT_EXIT=49 bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 49 ]]
  [[ ! -e "$HOME/.zshrc" && ! -e "$XDG_STATE_HOME/dotfiles" ]]
}

@test "interrupted plugin clones leave no published directory and retry cleanly" {
  run env MOCK_PARTIAL_CLONE=1 bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 41 ]]
  [[ ! -e "$HOME/.oh-my-zsh" ]]
  run find "$HOME" -name '.dotfiles-plugin-*'
  [[ "$status" == 0 && -z "$output" ]]
  run bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 0 ]]
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]
}

@test "bootstrap provisions shell Vim and tmux prerequisites" {
  run bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 0 ]]
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]
  [[ -f "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]
  [[ -f "$HOME/.vim/bundle/Vundle.vim/autoload/vundle.vim" ]]
  [[ -f "$HOME/.tmux/plugins/tpm/tpm" ]]
  [[ -f "$HOME/.tmux/plugins/tmux/catppuccin.tmux" ]]
  [[ -f "$HOME/.tmux/plugins/tmux-cpu/cpu.tmux" ]]
  [[ -f "$HOME/.tmux/plugins/tmux-battery/battery.tmux" ]]
  run grep -q 'git pull' "$MOCK_LOG"
  [[ "$status" == 1 ]]
}

@test "plugin revision mismatches never publish an installation" {
  run env MOCK_PIN_MISMATCH=1 bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 1 ]]
  [[ "$output" == *'verification failed'* ]]
  [[ ! -e "$HOME/.oh-my-zsh" && ! -e "$HOME/.zshrc" ]]
}

@test "plugin lock rejects traversal before invoking Git" {
  jq '.plugins[0].destination = "../outside"' "$REPO_ROOT/plugins.lock.json" > "$BATS_TEST_TMPDIR/invalid-lock.json"
  run bash -c 'source "$1/scripts/plugins.sh"; install_plugins "$2"' \
    dotfiles-test "$REPO_ROOT" "$BATS_TEST_TMPDIR/invalid-lock.json"
  [[ "$status" != 0 ]]
  [[ ! -e "$MOCK_LOG" ]]
}

@test "existing plugin installations are never implicitly updated" {
  mkdir -p "$HOME/.oh-my-zsh"
  touch "$HOME/.oh-my-zsh/oh-my-zsh.sh" "$HOME/.oh-my-zsh/local-customization"
  run bash "$REPO_ROOT/bootstrap.sh" --force
  [[ "$status" == 0 ]]
  [[ -f "$HOME/.oh-my-zsh/local-customization" ]]
  [[ ! -e "$HOME/.oh-my-zsh/.mock-revision" ]]
}

@test "bootstrap updates only a clean checkout and stops on update errors" {
  run env MOCK_GIT_DIRTY=' M .zshrc' bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --update
  [[ "$status" == 1 ]]
  [[ "$output" == *'Commit or stash'* ]]
  run grep -q 'git pull' "$MOCK_LOG"
  [[ "$status" == 1 ]]
  run env MOCK_GIT_DIRTY='' MOCK_GIT_EXIT=53 bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --update
  [[ "$status" == 53 ]]
  [[ ! -e "$HOME/.zshrc" ]]
}

run_shell() {
  local interpreter="$1"
  local script="$2"
  shift 2
  if [[ "$interpreter" == zsh ]]; then
    run env -i HOME="$HOME" PATH=/usr/bin:/bin TERM=xterm-256color \
      HOMEBREW_PREFIX="$HOME/homebrew" "$@" "$REAL_ZSH" -dfc "$script" dotfiles-test "$REPO_ROOT"
  else
    run env -i HOME="$HOME" PATH=/usr/bin:/bin TERM=xterm-256color \
      HOMEBREW_PREFIX="$HOME/homebrew" "$@" "$REAL_BASH" --noprofile --norc -c "$script" dotfiles-test "$REPO_ROOT"
  fi
}

@test "shared shell config loads with no kube files in Bash and zsh" {
  for interpreter in bash zsh; do
    run_shell "$interpreter" 'set -e; source "$1/.shrc"; alias ll >/dev/null; printf "%s" "${KUBECONFIG-unset}"'
    [[ "$status" == 0 && "$output" == unset ]]
  done
}

@test "shared shell config handles either kube file extension and spaces" {
  mkdir -p "$HOME/.kube"
  for extension in yaml yml; do
    touch "$HOME/.kube/cluster name.$extension"
    for interpreter in bash zsh; do
      run_shell "$interpreter" 'set -e; source "$1/.shrc"; printf "%s" "$KUBECONFIG"'
      [[ "$status" == 0 ]]
      [[ "$output" == "$HOME/.kube/cluster name.$extension" ]]
    done
    rm "$HOME/.kube/cluster name.$extension"
  done
}

@test "shared shell config includes default kubeconfig without empty path entries" {
  mkdir -p "$HOME/.kube"
  touch "$HOME/.kube/config" "$HOME/.kube/cluster.yaml" "$HOME/.kube/cluster.yml"
  for interpreter in bash zsh; do
    run_shell "$interpreter" 'set -e; source "$1/.shrc"; printf "%s" "$KUBECONFIG"'
    [[ "$status" == 0 ]]
    [[ "$output" == "$HOME/.kube/config:$HOME/.kube/cluster.yaml:$HOME/.kube/cluster.yml" ]]
  done
}

@test "shared shell config preserves supplied and intentionally empty kubeconfig" {
  for interpreter in bash zsh; do
    run_shell "$interpreter" 'set -e; source "$1/.shrc"; printf "%s" "$KUBECONFIG"' KUBECONFIG=/custom/config
    [[ "$status" == 0 && "$output" == /custom/config ]]
    run_shell "$interpreter" 'set -e; source "$1/.shrc"; printf "%s" "${KUBECONFIG+set}"' KUBECONFIG=
    [[ "$status" == 0 && "$output" == set ]]
  done
}

@test "shared shell config leaves parent glob options unchanged" {
  run_shell zsh 'set -e; source "$1/.shrc"; [[ ! -o NULL_GLOB ]]'
  [[ "$status" == 0 ]]
  run_shell bash 'set -e; source "$1/.shrc"; ! shopt -q nullglob'
  [[ "$status" == 0 ]]
}

@test "zsh environment uses portable Ruby paths and stable private environment" {
  mkdir -p "$HOME/homebrew/opt/ruby/bin" "$HOME/gems/current/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s" "$FAKE_GEM_BIN"\n' > "$HOME/homebrew/opt/ruby/bin/ruby"
  chmod +x "$HOME/homebrew/opt/ruby/bin/ruby"
  printf 'export DOTFILES_PRIVATE_CHECK=loaded\n' > "$HOME/.private_env"
  run_shell zsh 'set -e; source "$1/platforms/macos/shell.sh"; source "$1/.zshenv"; [[ "$DOTFILES_PRIVATE_CHECK" == loaded ]]; [[ ":$PATH:" == *":$HOMEBREW_PREFIX/opt/ruby/bin:"* ]]; [[ ":$PATH:" == *":$FAKE_GEM_BIN:"* ]]; [[ "$LDFLAGS" == -L*/homebrew/opt/ruby/lib ]]' FAKE_GEM_BIN="$HOME/gems/current/bin"
  [[ "$status" == 0 ]]
}

@test "zsh startup works without optional plugins uv or nvm" {
  cp "$REPO_ROOT/.shrc" "$HOME/.shrc"
  run_shell zsh 'set -e; source "$1/.zshrc"; [[ -n ${functions[compdef]} ]]; [[ -z ${functions[node]-} ]]; [[ "$HISTFILE" == "$HOME/.zsh_history" ]]; printf PROFILE_READY'
  [[ "$status" == 0 && "$output" == PROFILE_READY ]]
  [[ ! -d "$HOME/.zsh/completions" ]]
}

make_oc_fixture() {
  cat > "$HOME/bin/oc" <<'MOCK'
#!/usr/bin/env sh
printf 'compdef _arguments oc\n'
MOCK
  chmod +x "$HOME/bin/oc"
}

@test "personal profile skips OpenShift completion even when oc is installed" {
  make_oc_fixture
  run_shell zsh 'set -e; source "$1/.zshrc"; [[ "$DOTFILES_PROFILE" == personal ]]; [[ -z ${_comps[oc]-} ]]' PATH="$HOME/bin:/usr/bin:/bin"
  [[ "$status" == 0 ]]
}

@test "work profile enables OpenShift completion" {
  make_oc_fixture
  run_shell zsh 'set -e; source "$1/.zshrc"; [[ ${_comps[oc]-} == _arguments ]]' PATH="$HOME/bin:/usr/bin:/bin" DOTFILES_PROFILE=work
  [[ "$status" == 0 ]]
}

@test "saved profiles support per-terminal overrides and reject unknown values" {
  make_oc_fixture
  mkdir -p "$HOME/.config/dotfiles"
  printf 'work\n' > "$HOME/.config/dotfiles/profile"
  run_shell zsh 'set -e; source "$1/.zshrc"; [[ "$DOTFILES_PROFILE" == work ]]; [[ ${_comps[oc]-} == _arguments ]]' PATH="$HOME/bin:/usr/bin:/bin"
  [[ "$status" == 0 ]]
  run_shell zsh 'set -e; source "$1/.zshrc"; [[ "$DOTFILES_PROFILE" == personal ]]; [[ -z ${_comps[oc]-} ]]' PATH="$HOME/bin:/usr/bin:/bin" DOTFILES_PROFILE=personal
  [[ "$status" == 0 ]]
  run_shell zsh 'source "$1/.zshrc"' DOTFILES_PROFILE=unknown
  [[ "$status" == 1 && "$output" == *'Invalid DOTFILES_PROFILE'* ]]
}

@test "deployed layers preserve common settings and personal work completion differences" {
  make_oc_fixture
  for platform in macos ubuntu; do
    for profile in personal work; do
      run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform "$platform" --profile "$profile"
      [[ "$status" == 0 ]]
      run_shell zsh 'set -e; source "$HOME/.zshrc"; [[ "$DOTFILES_PROFILE" == "$EXPECTED_PROFILE" ]]; alias awsls >/dev/null; if [[ "$DOTFILES_PROFILE" == work ]]; then [[ ${_comps[oc]-} == _arguments ]]; else [[ -z ${_comps[oc]-} ]]; fi' \
        PATH="$HOME/bin:/usr/bin:/bin" EXPECTED_PROFILE="$profile"
      [[ "$status" == 0 ]]
      grep -Fq '../dotfiles/platform.d/ghostty.conf' "$XDG_CONFIG_HOME/ghostty/config"
    done
  done
}

@test "Ubuntu clipboard prefers Wayland and local overrides are not managed" {
  printf '#!/usr/bin/env sh\nexit 0\n' > "$HOME/bin/wl-copy"
  chmod +x "$HOME/bin/wl-copy"
  mkdir -p "$XDG_CONFIG_HOME/dotfiles/local"
  printf 'export DOTFILES_LOCAL_CHECK=kept\n' > "$XDG_CONFIG_HOME/dotfiles/local/shell.sh"
  run bash "$REPO_ROOT/bootstrap.sh" --force --skip-install --platform ubuntu
  [[ "$status" == 0 ]]
  run_shell bash 'set -e; source "$HOME/.shrc"; [[ "$DOTFILES_LOCAL_CHECK" == kept ]]; [[ $(alias copy) == *wl-copy* ]]' PATH="$HOME/bin:/usr/bin:/bin"
  [[ "$status" == 0 ]]
}

@test "Git work identity follows repository paths rather than shell profile" {
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$REPO_ROOT/.gitconfig"
  printf '[user]\n  name = Work Identity\n  email = work@example.invalid\n' > "$HOME/.gitconfig.work"
  "$REAL_GIT" init -q "$HOME/work/project"
  "$REAL_GIT" init -q "$HOME/personal-project"
  run env DOTFILES_PROFILE=personal "$REAL_GIT" -C "$HOME/work/project" config user.email
  [[ "$status" == 0 && "$output" == work@example.invalid ]]
  run env DOTFILES_PROFILE=work "$REAL_GIT" -C "$HOME/personal-project" config user.email
  [[ "$status" == 0 && "$output" != work@example.invalid ]]
}

@test "Ubuntu desktop shortcut preview never touches the session" {
  run ruby "$REPO_ROOT/platforms/ubuntu/desktop.rb" --dry-run
  [[ "$status" == 0 && "$output" == *'switch-to-workspace-left'* ]]
  [[ "$output" != *'<Alt>j'* && ! -e "$XDG_STATE_HOME/dotfiles/desktop-backups" ]]
  run env XDG_CURRENT_DESKTOP= DBUS_SESSION_BUS_ADDRESS= ruby "$REPO_ROOT/platforms/ubuntu/desktop.rb"
  [[ "$status" == 1 && "$output" == *'GNOME desktop session'* ]]
}

@test "Ubuntu desktop changes require confirmation and save restorable values" {
  cat > "$HOME/bin/gsettings" <<'MOCK'
#!/usr/bin/env bash
printf 'gsettings %s\n' "$*" >> "$MOCK_LOG"
if [[ "$1" == get ]]; then printf "['original-shortcut']\n"; fi
MOCK
  chmod +x "$HOME/bin/gsettings"
  run bash -c 'printf "no\n" | env XDG_CURRENT_DESKTOP=GNOME DBUS_SESSION_BUS_ADDRESS=fixture ruby "$1"' \
    dotfiles-test "$REPO_ROOT/platforms/ubuntu/desktop.rb"
  [[ "$status" == 0 && "$output" == *Cancelled* ]]
  run grep -q 'gsettings set' "$MOCK_LOG"
  [[ "$status" == 1 ]]
  run bash -c 'printf "desktop\n" | env XDG_CURRENT_DESKTOP=GNOME DBUS_SESSION_BUS_ADDRESS=fixture ruby "$1"' \
    dotfiles-test "$REPO_ROOT/platforms/ubuntu/desktop.rb"
  [[ "$status" == 0 ]]
  snapshots=("$XDG_STATE_HOME"/dotfiles/desktop-backups/*/settings.json)
  run jq -e '.version == 1 and all(.settings[]; .value == "[\u0027original-shortcut\u0027]")' "${snapshots[0]}"
  [[ "$status" == 0 ]]
  run ruby "$REPO_ROOT/platforms/ubuntu/desktop.rb" --restore "${snapshots[0]}" --dry-run
  [[ "$status" == 0 && "$output" == *original-shortcut* ]]
}

make_git_fixture() {
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="$REPO_ROOT/.gitconfig"
  GIT_FIXTURE="$BATS_TEST_TMPDIR/git-fixture"
  "$REAL_GIT" init -q "$GIT_FIXTURE"
  "$REAL_GIT" -C "$GIT_FIXTURE" config user.name 'Dotfiles Tests'
  "$REAL_GIT" -C "$GIT_FIXTURE" config user.email dotfiles@example.invalid
  printf 'original\n' > "$GIT_FIXTURE/tracked.txt"
  "$REAL_GIT" -C "$GIT_FIXTURE" add tracked.txt
  "$REAL_GIT" -C "$GIT_FIXTURE" commit -qm first
  FIRST_COMMIT="$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)"
  "$REAL_GIT" -C "$GIT_FIXTURE" commit -qm second --allow-empty
  SECOND_COMMIT="$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)"
}

@test "git undo refuses unstaged staged and untracked changes" {
  make_git_fixture
  printf 'edited\n' > "$GIT_FIXTURE/tracked.txt"
  run "$REAL_GIT" -C "$GIT_FIXTURE" undo
  [[ "$status" == 1 && "$output" == *'Refusing to discard'* ]]
  "$REAL_GIT" -C "$GIT_FIXTURE" add tracked.txt
  run "$REAL_GIT" -C "$GIT_FIXTURE" undo
  [[ "$status" == 1 && "$output" == *'Refusing to discard'* ]]
  "$REAL_GIT" -C "$GIT_FIXTURE" restore --staged --worktree tracked.txt
  touch "$GIT_FIXTURE/untracked.txt"
  run "$REAL_GIT" -C "$GIT_FIXTURE" undo
  [[ "$status" == 1 && "$output" == *'Refusing to discard'* ]]
  [[ "$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)" == "$SECOND_COMMIT" ]]
}

@test "git undo resets only after explicit confirmation" {
  make_git_fixture
  run bash -c 'printf "n\n" | "$1" -C "$2" undo' dotfiles-test "$REAL_GIT" "$GIT_FIXTURE"
  [[ "$status" == 1 && "$output" == *Cancelled* ]]
  [[ "$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)" == "$SECOND_COMMIT" ]]
  run bash -c 'printf "undo\n" | "$1" -C "$2" undo' dotfiles-test "$REAL_GIT" "$GIT_FIXTURE"
  [[ "$status" == 0 ]]
  [[ "$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)" == "$FIRST_COMMIT" ]]
}

@test "git undo validates requested reflog targets before confirmation" {
  make_git_fixture
  run "$REAL_GIT" -C "$GIT_FIXTURE" undo 99999
  [[ "$status" != 0 ]]
  [[ "$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)" == "$SECOND_COMMIT" ]]
}

@test "git undo protects edits made while confirmation is pending" {
  make_git_fixture
  printf 'committed update\n' > "$GIT_FIXTURE/tracked.txt"
  "$REAL_GIT" -C "$GIT_FIXTURE" add tracked.txt
  "$REAL_GIT" -C "$GIT_FIXTURE" commit -qm third
  latest_commit="$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)"
  undo_alias="$("$REAL_GIT" config --get alias.undo)"
  run env PATH="${REAL_GIT%/*}:/usr/bin:/bin" "$REAL_BASH" --noprofile --norc -c \
    'cd "$2"; read() { printf "late edit\n" > tracked.txt; reply=undo; }; eval "$1"' \
    dotfiles-test "${undo_alias#!}" "$GIT_FIXTURE"
  [[ "$status" != 0 ]]
  grep -qx 'late edit' "$GIT_FIXTURE/tracked.txt"
  [[ "$("$REAL_GIT" -C "$GIT_FIXTURE" rev-parse HEAD)" == "$latest_commit" ]]
}

run_nvim() {
  run env DOTFILES_REPO="$REPO_ROOT" "$REAL_NVIM" --headless -u NONE --noplugin -i NONE -n \
    "+lua local ok, error_message = pcall(function() $1 end); if not ok then io.stderr:write(tostring(error_message) .. '\\n'); vim.cmd('cquit 1') end" +qa
}

@test "Neovim explicitly enables its configured LSP servers" {
  run_nvim '
    package.preload["cmp_nvim_lsp"] = function()
      return { default_capabilities = function() return { dotfiles_test = true } end }
    end
    local specifications = dofile(vim.env.DOTFILES_REPO .. "/nvim/.config/nvim/lua/plugins/lsp-config.lua")
    local servers = specifications[2].opts.ensure_installed
    assert(#servers == 4)
    for _, server in ipairs(servers) do
      vim.lsp.config(server, { cmd = { "false" }, filetypes = { "dotfiles_test" } })
    end
    specifications[3].config()
    for _, server in ipairs(servers) do
      assert(vim.lsp.is_enabled(server), server .. " is disabled")
      assert(vim.lsp.config[server].capabilities.dotfiles_test)
    end
    assert(specifications[2].opts.automatic_enable == servers)
  '
  [[ "$status" == 0 ]]
}

@test "Neovim declares and pins its buffer completion provider" {
  run_nvim '
    local specifications = dofile(vim.env.DOTFILES_REPO .. "/nvim/.config/nvim/lua/plugins/completions.lua")
    local declared = false
    for _, specification in ipairs(specifications) do
      if specification[1] == "hrsh7th/cmp-buffer" then declared = true end
    end
    assert(declared)
    local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.env.DOTFILES_REPO .. "/nvim/.config/nvim/lazy-lock.json"), "\n"))
    assert(lock["cmp-buffer"] and #lock["cmp-buffer"].commit == 40)
  '
  [[ "$status" == 0 ]]
}

@test "Brewfile provisions formatters and shell linting" {
  run ruby -e '
    class Manifest
      attr_reader :formulae
      def initialize; @formulae = []; end
      def brew(name, **options); @formulae << name; end
      %i[tap cask vscode npm].each { |kind| define_method(kind) { |*args, **options| } }
    end
    manifest = Manifest.new
    manifest.instance_eval(File.read(ARGV.fetch(0)))
    missing = %w[stylua isort prettier rubocop shellcheck] - manifest.formulae
    abort "Missing packages: #{missing.join(", ")}" unless missing.empty?
  ' "$REPO_ROOT/Brewfile"
  [[ "$status" == 0 ]]
}

@test "Homebrew audit reports deprecated packages without editing the manifest" {
  printf 'cask "whisky"\n' > "$BATS_TEST_TMPDIR/audit-Brewfile"
  printf '{"casks":[{"token":"whisky","deprecated":true,"disabled":false,"deprecation_reason":"unmaintained"}]}\n' > "$BATS_TEST_TMPDIR/brew-info.json"
  before="$(cat "$BATS_TEST_TMPDIR/audit-Brewfile")"
  run env MOCK_BREW_INFO="$BATS_TEST_TMPDIR/brew-info.json" ruby "$REPO_ROOT/scripts/audit-brewfile.rb" "$BATS_TEST_TMPDIR/audit-Brewfile"
  [[ "$status" == 0 && "$output" == *'DEPRECATED cask whisky: unmaintained'* ]]
  [[ "$(cat "$BATS_TEST_TMPDIR/audit-Brewfile")" == "$before" ]]
  run grep -E 'install|uninstall|cleanup' "$MOCK_LOG"
  [[ "$status" == 1 ]]
}

@test "Homebrew audit reports disabled entries and fails on unavailable metadata" {
  printf 'brew "old-formula"\n' > "$BATS_TEST_TMPDIR/audit-Brewfile"
  printf '{"formulae":[{"name":"old-formula","full_name":"old-formula","deprecated":true,"disabled":true,"disable_reason":"unsupported","disable_replacement_formula":"new-formula"}]}\n' > "$BATS_TEST_TMPDIR/brew-info.json"
  run env MOCK_BREW_INFO="$BATS_TEST_TMPDIR/brew-info.json" ruby "$REPO_ROOT/scripts/audit-brewfile.rb" "$BATS_TEST_TMPDIR/audit-Brewfile"
  [[ "$status" == 0 && "$output" == *'DISABLED formula old-formula'* && "$output" == *'new-formula'* ]]
  run env MOCK_BREW_INFO_EXIT=29 ruby "$REPO_ROOT/scripts/audit-brewfile.rb" "$BATS_TEST_TMPDIR/audit-Brewfile"
  [[ "$status" == 1 && "$output" == *'metadata query failed'* ]]
}

@test "tmux starts without missing optional plugins" {
  TMUX_SOCKET="$BATS_TEST_TMPDIR/tmux.sock"
  run env TMUX= "$REAL_TMUX" -S "$TMUX_SOCKET" -f "$REPO_ROOT/.tmux.conf" new-session -d -s dotfiles-test
  [[ "$status" == 0 ]]
  run "$REAL_TMUX" -S "$TMUX_SOCKET" source-file -n "$REPO_ROOT/.tmux.conf"
  [[ "$status" == 0 ]]
  run "$REAL_TMUX" -S "$TMUX_SOCKET" show-options -gqv prefix
  [[ "$status" == 0 && "$output" == C-s ]]
}

@test "tmux uses the same plugin directories as bootstrap" {
  for plugin in tmux-cpu tmux-battery; do
    grep -Fq "tmux-plugins/$plugin'" "$REPO_ROOT/.tmux.conf"
    grep -Fq ".tmux/plugins/$plugin/" "$REPO_ROOT/.tmux.conf"
  done
  run grep -F '.config/tmux/plugins' "$REPO_ROOT/.tmux.conf"
  [[ "$status" == 1 ]]
}

@test "editor shortcuts do not conflict with AeroSpace" {
  run_nvim '
    dofile(vim.env.DOTFILES_REPO .. "/nvim/.config/nvim/lua/keymaps.lua")
    for _, mode in ipairs({"n", "v"}) do
      assert(vim.fn.maparg("<A-j>", mode) == "")
      assert(vim.fn.maparg("<A-k>", mode) == "")
      assert(vim.fn.maparg("<A-S-j>", mode) ~= "")
      assert(vim.fn.maparg("<A-S-k>", mode) ~= "")
    end
  '
  [[ "$status" == 0 ]]
  for shortcut in j k; do
    grep -Fq "alt-$shortcut = 'focus" "$REPO_ROOT/.aerospace.toml"
    grep -Fq "nnoremap <A-S-$shortcut>" "$REPO_ROOT/.vimrc"
  done
}

@test "Vim starts with core settings when Vundle is absent" {
  run "$REAL_VIM" -Nu "$REPO_ROOT/.vimrc" -i NONE -n -es -c 'qa!'
  [[ "$status" == 0 ]]
}




