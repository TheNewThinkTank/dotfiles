.PHONY: check lint test integration audit ubuntu

check: lint test

lint:
	bash -n bootstrap.sh
	bash -n .bashrc
	bash -n .shrc
	zsh -n .zshrc
	zsh -n .zshenv
	zsh -n .p10k.zsh
	zsh -n .shrc
	zsh -n profiles/work/shell.zsh
	shellcheck -x --exclude=SC1091 bootstrap.sh common/shell/environment.sh platforms/macos/*.sh platforms/ubuntu/*.sh scripts/plugins.sh tests/integration.sh
	shellcheck -x --exclude=SC1091 tests/ubuntu.sh
	shellcheck --exclude=SC2016,SC2030,SC2031 tests/dotfiles.bats
	ruby -c Brewfile
	ruby -c scripts/backups.rb
	ruby -c scripts/audit-brewfile.rb
	ruby -c platforms/ubuntu/desktop.rb
	ruby -c tests/docker.rb
	git config --file=.gitconfig --list > /dev/null
	jq empty plugins.lock.json platforms/ubuntu/tools.lock.json platforms/ubuntu/desktop-settings.json common/nvim/lazy-lock.json common/nvim/lua/.luarc.json common/nvim/lua/plugins/.luarc.json
	yq -p=toml -o=json .aerospace.toml > /dev/null
	yq -o=json .github/workflows/ci.yml | jq -e '.on.push != null and .on.pull_request != null and .permissions.contents == "read"' > /dev/null
	nvim --headless -u NONE --noplugin -i NONE -n '+lua for _, config_file in ipairs(vim.fn.glob("common/nvim/**/*.lua", false, true)) do local chunk, error_message = loadfile(config_file); if not chunk then io.stderr:write(error_message .. "\n"); vim.cmd("cquit 1") end end' +qa
	nvim --headless -u NONE --noplugin -i NONE -n '+lua assert(loadfile("tests/integration.lua"))' +qa
	./bootstrap.sh --dry-run --skip-install > /dev/null
	git diff --check

test:
	bats tests/dotfiles.bats

integration:
	bash tests/integration.sh

audit:
	ruby scripts/audit-brewfile.rb

ubuntu:
	ruby tests/docker.rb


