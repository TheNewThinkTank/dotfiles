# dotfiles

Dotfiles for macOS and Ubuntu Desktop 26.04 LTS.
Includes config for zsh, tmux, nvim, git and more.

## Platforms And Profiles

Platform and profile are independent: `macos` or `ubuntu`, and `personal` or
`work`. Platform is detected from the operating system unless explicitly selected.
Personal is the default profile. Both profiles use the same tools and shared
configuration; only work explicitly loads OpenShift zsh completion.

Package selection is independent too: `workstation` is the unchanged default
for macOS and Ubuntu. Ubuntu also supports `--package-set homelab`, which installs
only the shared shell/editor prerequisites and official kubectl, without desktop
applications, OpenShift, language-formatting tools, or font downloads. macOS
rejects that reduced package set rather than silently changing new MacBook setup.

```bash
# Personal macOS
./bootstrap.sh --platform macos --profile personal --dry-run
./bootstrap.sh --platform macos --profile personal

# Work macOS
./bootstrap.sh --platform macos --profile work

# Personal Ubuntu 26.04
./bootstrap.sh --platform ubuntu --profile personal --dry-run
./bootstrap.sh --platform ubuntu --profile personal

# Lightweight Ubuntu homelab user environment
./bootstrap.sh --platform ubuntu --profile personal --package-set homelab --dry-run
./bootstrap.sh --platform ubuntu --profile personal --package-set homelab
```

Bootstrap saves validated choices under `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles`
as `profile`, `platform`, and `package-set`. These machine-local files are not committed. Subsequent
configuration deployments retain the saved profile. `DOTFILES_PROFILE=work zsh`
or `DOTFILES_PROFILE=personal zsh` overrides it for an individual terminal.
Bootstrap flags take precedence over environment variables and saved defaults.

Settings load in the order shared configuration, platform, profile, then local
overrides. Do not select work mode by hostname or username.

## Repository Layout

```text
common/
	shell/                 shared Bash/zsh configuration
	git/                   shared Git config and work-identity example
	tmux/                  shared tmux config
	vim/                   shared Vim config
	nvim/                  shared Neovim config and plugin lock
	ghostty/               shared terminal config
platforms/
	macos/                 Brewfile, AeroSpace, shell and Ghostty settings
	ubuntu/                APT packages, pinned tools, shell and desktop setup
profiles/
	work/shell.zsh         OpenShift completion only
scripts/                 pinned plugins, backups, restore and package audit
tests/                   offline, native integration and Docker checks
```

Root dotfile paths, `Brewfile`, `nvim/.config/nvim`, and `ghostty/.config/ghostty`
are compatibility links to the canonical files above, not separate copies.
Deployment dereferences these repository links and installs file contents with
backups. Prefer editing the canonical files when adding new configuration.

Untracked overrides can live in `~/.gitconfig.local`, `~/.gitconfig.work`, and
`${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local/`: `environment.sh`, `shell.sh`,
and `ghostty.conf`. Bootstrap never copies over those local override files.

Private environment variables belong in `~/.private_env`. Bootstrap creates it
from `private_env.template` with owner-only permissions if it does not exist.
An existing checkout-local `.private_env` is migrated only when the home copy is
absent; existing home credentials are never overwritten.

## Bootstrap (fresh machine)

```bash
git clone https://github.com/TheNewThinkTank/dotfiles.git ~/Documents/projects/dotfiles
cd ~/Documents/projects/dotfiles
./bootstrap.sh --dry-run
./bootstrap.sh
```

Bootstrap asks for confirmation before installing or changing anything. It:
1. Uses Homebrew on macOS or APT plus verified user-local tools on Ubuntu.
2. Installs missing platform packages without deleting installed packages or
   running cleanup. The macOS Brewfile is preserved intact.
3. Installs missing Oh My Zsh, Powerlevel10k, Vundle, TPM, and tmux plugins at
	verified commits from `plugins.lock.json`.
4. Copies managed dotfiles to `~` and Neovim/Ghostty configuration to
   `${XDG_CONFIG_HOME:-$HOME/.config}`, skipping AeroSpace on Ubuntu.
5. Saves replaced files beneath
   `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/` and prints the backup
   directory. Files not managed by this repo are left alone; nothing is deleted.

Open a new terminal afterward. The script does not source zsh configuration from
Bash or reload running tmux/AeroSpace sessions.

## Updating Configuration

Edit files in this checkout, then deploy them with backups:

```bash
./bootstrap.sh --dry-run --skip-install
./bootstrap.sh --skip-install
./bootstrap.sh --check
```

`--dry-run` prints the plan without installing packages, contacting remotes, or
writing files. `--skip-install` only deploys configuration. `--force` skips the
confirmation prompt, not backups. `--update` explicitly fast-forwards a clean
checkout from `origin/main`; bootstrap never pulls automatically.

`--check` is a read-only configuration comparison: exit 0 means managed content
and saved selectors match, exit 3 means deployment is needed, and other nonzero
statuses are errors. It does not install packages, inspect secret contents, or
contact Git remotes. It checks configuration, not the whole package/plugin state.
The plugin helper has an independent read-only interface:

```bash
bash scripts/plugins.sh plugins.lock.json check
bash scripts/plugins.sh plugins.lock.json install
```

An unchanged configuration deployment creates no extra backup. A real content
change still uses the existing backup/restore mechanism, including edits that
preserve file size and timestamps. Extra local files and overrides are retained.

Bootstrap copies configuration rather than creating symlinks. Existing links
directly to this checkout are preserved. Backups contain the prior home files
under `home/` and app configuration under `config/nvim/` and `config/ghostty/`.
The installed layer files and saved selectors are backed up under
`config/dotfiles/` as well.

## Restoring Backups

Each deployment writes an owner-only `manifest.json` beside its backups. It
records destination roots, checksums, file modes, platform/profile, and whether deployment
completed or failed. A failed deployment still records files already replaced.

Use the backup directory printed by bootstrap:

```bash
./bootstrap.sh --restore /path/to/backup --dry-run
./bootstrap.sh --restore /path/to/backup
```

Restore verifies payloads, home/config roots, and destination boundaries before
showing its plan. It requires the exact confirmation `restore`; `--force` cannot
bypass this prompt. Current files are saved to a new rollback backup before
replacement. Files absent from the saved backup are not deleted, and unrelated
files and private credentials are left alone. Restore rechecks integrity and
scope after confirmation. Backups made before manifests were introduced must be
restored manually.

## Pinned Dependencies

New shell, Vim, and tmux installations are staged in temporary sibling
directories and published only after their Git revision and entrypoint match
`plugins.lock.json`. Failed clones discard only their staging directory and can
be retried. Existing plugin installations and local customizations are not
silently updated or deleted; incomplete pre-existing installations stop with a
diagnostic.

To update pins explicitly, review an upstream revision and edit the corresponding
commit in `plugins.lock.json`, then run `make integration`. Deploy updates to
existing plugin checkouts deliberately after preserving local changes. Neovim
uses its separate `lazy-lock.json`, including a staged, verified initial Lazy
installation. Regular configuration deployment does not update dependency pins.

## Zsh config

- [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

Homebrew paths are discovered rather than assuming Apple Silicon or Intel paths.
Ruby's gem executable directory is obtained from RubyGems, not a fixed Ruby
version. An existing `KUBECONFIG` is preserved. Otherwise the shared shell config
combines `~/.kube/config`, `*.yaml`, and `*.yml` files when present, without empty
path entries. Missing directories or either file extension are supported in Bash
and zsh. Work loads OpenShift completion only when `oc` is available. Personal
does not run `oc completion zsh`, even if the tool is installed. System-provided
autoload completion files may still exist independently of the profile.

Ubuntu loads its native zsh highlighting/autosuggestion files from `/usr/share`
and prefers `wl-copy` for clipboard operations, with X11 alternatives available.

## Vim config

```bash
vim +PluginInstall +qall
```

Bootstrap provisions Vundle. Vim still loads core settings if Vundle is absent.

## Neovim config

Located in `common/nvim/`. Requires Neovim 0.11.3 or newer. Lazy installs
plugins from the committed lockfile on first startup. Mason installs the
TypeScript, Ruby, HTML, and Lua servers; all four are explicitly enabled using
`vim.lsp.enable`. Run `:checkhealth vim.lsp` to inspect server status.

The Brewfile provisions StyLua, isort, Prettier, and RuboCop for formatting, while
buffer completion is provided by `cmp-buffer`. Prettier can also use a project's
local installation.

Vim and Neovim move lines with Shift-Alt-j/k in normal and visual mode. Alt-j/k
remain AeroSpace's window-focus shortcuts. Ghostty uses the left Option key as
Alt on macOS. Ghostty loads shared settings first, then the selected platform's
native include and an optional local include.

## Ubuntu Desktop

`platforms/ubuntu/apt-packages.txt` uses explicit native package mappings rather
than translating Homebrew names: examples include `fd-find`, `isort`,
`tealdeer`, and `wl-clipboard`. Ghostty is available in Ubuntu 26.04's official
archive. Linuxbrew is not installed.

The installer uses APT without package removals, upgrades, or extra recommends.
Non-root users must authorize sudo in their own terminal with `sudo -v` before
setup; the script only uses noninteractive sudo. Configuration-only deployments
with `--skip-install` do not require privilege escalation.

Checksum-pinned kubectl comes directly from Kubernetes at `dl.k8s.io`, currently
`v1.37.1` for x86_64 and aarch64. The installed client version is checked. OpenShift
is a separate `oc`-only download in the workstation package set and can never
publish or replace kubectl. The lightweight homelab set does not install `oc`.

If required tools are missing, workstation assets provide StyLua and Mike Farah
yq, plus Neovim if APT's version is too old.
Prettier is version-pinned under `~/.local`; a verified JetBrains Mono Nerd Font
is installed per user. Existing local binaries are not silently replaced.
Assets cover x86_64 and aarch64 in `platforms/ubuntu/tools.lock.json`.

Existing user-local binaries are preserved. If your current kubectl came from
the older OpenShift bundle, back it up and deliberately relocate it before
selecting the official client. Updating an asset pin is not permission to
overwrite a custom executable silently. On macOS, the full Brewfile includes
Homebrew's official `kubernetes-cli` formula, Helm 3, Gitleaks, and actionlint in
addition to the existing Terraform/Ansible/uv setup. Check client/server version
compatibility when administering older Kubernetes clusters.

GNOME desktop shortcuts are separate and opt-in:

```bash
ruby platforms/ubuntu/desktop.rb --dry-run
ruby platforms/ubuntu/desktop.rb
ruby platforms/ubuntu/desktop.rb --restore /path/to/settings.json --dry-run
ruby platforms/ubuntu/desktop.rb --restore /path/to/settings.json
```

Run changes in your GNOME desktop session and confirm with the exact word
`desktop`. Prior settings are saved under the dotfiles state directory for
restoration. Workspace shortcuts use Super-h/l and Shift-Super-h/l, leaving
editor Alt bindings free. Ordinary bootstrap never changes desktop keybindings.

## Tmux

All plugins are installed beneath `~/.tmux/plugins`: TPM, Catppuccin, tmux-cpu,
and tmux-battery. Missing plugins are skipped rather than breaking startup. The
prefix remains Ctrl-s. Use prefix-r to reload the config after deployment.

## Homebrew

```bash
# Inspect installed entries without replacing the maintained Brewfile
brew bundle dump --file=-

# Install brew packages
brew bundle install --no-upgrade --file ./Brewfile
```

Merge new installed entries into the Brewfile additively. Keep existing entries
unless their removal has been explicitly approved. Do not use a forced dump or
`brew bundle cleanup` to synchronize this file.

Run a read-only metadata audit:

```bash
make audit
```

It reports deprecated/disabled formulae and casks, plus Homebrew-provided
replacement suggestions. It does not install, uninstall, or edit entries.
Metadata lookup failures return an error rather than a false clean report.

The disabled `tldr` formula was replaced with its maintained `tlrc` replacement
with explicit approval. No other existing formula or cask was removed. Run the
audit before a new-machine setup; deprecation warnings are reported without
silently pruning your maintained package list. Disabled future entries can still
block installation and need a reviewed replacement.

## Homelab Integration

The sibling homelab project can opt into user configuration from a full published
commit SHA of this repository. Publish the new bootstrap/package/client interface
before selecting that commit; a moving branch is not a reproducible dependency.
The Ansible role reads the lightweight package manifest and tool lock from that
revision, manages APT state separately, installs only missing pinned plugins, and
deploys configuration only when `--check` detects differences. It runs user tasks
as `ubuntu`, not root. System hardening, Desktop installation, Kubernetes, and
monitoring stay in the homelab project.

Homelab never copies the administrator workstation's private environment,
overrides, SSH keys, or kubeconfig to guests. Its `make kube-shell` explicitly
selects the project-private kubeconfig only for a child controller shell, using
the existing shell completions without changing global dotfiles or merging
administrator credentials into every VM.

## Git tips

Git identity is selected by repository location, not shell profile. Repositories
under `~/work/` or `~/Documents/work/` include `~/.gitconfig.work`; other directories
keep your shared personal identity. Copy `common/git/work.gitconfig.example` to
that home file and fill in your work identity. Additional directory rules can be
kept in `~/.gitconfig.local`. Credentials and private work settings stay outside
the repository.

```bash
# Tell git to use its built-in language parser for md files
echo '*.md diff=markdown' >> .gitattributes

# Search for changes to the README files' Usage section
git lg -L:Usage:README.md
```

`git undo [reflog-step]` requires a clean worktree, including no untracked files,
and the exact confirmation `undo`. It uses `git reset --keep` so edits made while
confirmation is pending are not discarded.

## Verification

```bash
brew install bats-core jq neovim shellcheck tmux yq
make check

# Networked checks with real pinned dependencies in temporary state
brew install stylua isort prettier rubocop
make integration

# Ubuntu 26.04 container: native package setup and both profiles
make ubuntu

# Native lightweight Ubuntu setup and repeat-run checks
DOTFILES_PACKAGE_SET=homelab make ubuntu
```

The checks cover shell syntax, ShellCheck, Lua/JSON/TOML/YAML configuration,
bootstrap dry runs, and isolated Bats regressions for failed-clone recovery, pin
verification, backup manifests, restore confirmation and integrity, credentials,
kubeconfig, Git undo, LSP activation, tmux paths, and editor shortcuts.
ShellCheck's SC2016, SC2030, and SC2031 diagnostics are excluded only for Bats:
child-shell expressions are deliberately single-quoted and Bats runs each test
with its own status variables. Production shell scripts retain full linting.

`make check` is offline and does not download plugins. `make integration` installs
the real locked shell/Vim/tmux/Neovim dependencies into an isolated temporary home,
checks every Neovim commit, exercises actual startup, and verifies real LSP
defaults and completion providers. The integration-only Mason option disables
language-server downloads; normal Neovim startup still provisions its four
servers. Tests do not deploy live dotfiles or reset the working repository.
CI covers personal and work profiles on macOS and in an Ubuntu 26.04 container.
Separate native Ubuntu jobs cover both workstation and homelab package sets.
`make ubuntu` requires a running Docker daemon and mounts a read-only public-file
snapshot; private environment files and local overrides are excluded. It retains
full logs and result metadata in the temporary result directory it prints.
If your Docker network requires host-managed CA trust, explicitly run
`DOTFILES_DOCKER_USE_HOST_CA=1 make ubuntu` on macOS. This exports public CA
certificates verified by macOS into the disposable container only. TLS and asset
checksum verification remain enabled; host trust settings and credentials are
not changed.
Desktop session behavior still needs a real GNOME/Wayland session; container
checks validate its preview, confirmation, and restore contracts instead.
