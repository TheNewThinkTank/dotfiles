local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  local revision = lock["lazy.nvim"].commit
  assert(revision:match("^[0-9a-f]+$") and #revision == 40, "Invalid Lazy revision in lockfile")
  vim.fn.mkdir(vim.fn.fnamemodify(lazypath, ":h"), "p")
  local staging = lazypath .. ".install-" .. vim.fn.getpid()
  local commands = {
    { "git", "clone", "--quiet", "--filter=blob:none", "--no-checkout", "https://github.com/folke/lazy.nvim.git", staging },
    { "git", "-C", staging, "fetch", "--quiet", "--depth=1", "origin", revision },
    { "git", "-C", staging, "checkout", "--quiet", "--detach", "FETCH_HEAD" },
  }
  for _, command in ipairs(commands) do
    local output = vim.fn.system(command)
    if vim.v.shell_error ~= 0 then
      vim.fn.delete(staging, "rf")
      error("Lazy installation failed: " .. output)
    end
  end
  local installed = vim.fn.trim(vim.fn.system({ "git", "-C", staging, "rev-parse", "HEAD" }))
  if vim.v.shell_error ~= 0 or installed ~= revision or not vim.uv.fs_stat(staging .. "/lua/lazy/init.lua") then
    vim.fn.delete(staging, "rf")
    error("Lazy installation did not match its committed pin")
  end
  local published, error_message = vim.uv.fs_rename(staging, lazypath)
  if not published then
    vim.fn.delete(staging, "rf")
    error("Could not publish Lazy installation: " .. tostring(error_message))
  end
end
vim.opt.rtp:prepend(lazypath)

require("vim-options")
require("keymaps")
local specifications = { { import = "plugins" } }
if vim.g.dotfiles_integration_check then
  specifications[#specifications + 1] = {
    "mason-org/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  }
end
require("lazy").setup(specifications)

vim.cmd([[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NonText guibg=NONE ctermbg=NONE
]])

