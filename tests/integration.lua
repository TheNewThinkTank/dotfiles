local startup_errors = {}
local original_notify = vim.notify
vim.notify = function(message, level, options)
  if level and level >= vim.log.levels.ERROR then
    startup_errors[#startup_errors + 1] = tostring(message)
  end
  return original_notify(message, level, options)
end

local success, failure = xpcall(function()
  vim.g.dotfiles_integration_check = true
  vim.opt.loadplugins = true
  vim.opt.rtp:prepend(vim.fn.stdpath("config"))
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  vim.cmd("Lazy! restore")

  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  local configuration = require("lazy.core.config")
  for name, pin in pairs(lock) do
    local plugin = assert(configuration.plugins[name], "Locked plugin is not declared: " .. name)
    local revision = vim.fn.trim(vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }))
    assert(vim.v.shell_error == 0 and revision == pin.commit, "Plugin revision mismatch: " .. name)
  end
  for _, server in ipairs({ "ts_ls", "solargraph", "html", "lua_ls" }) do
    local config = vim.lsp.config[server]
    assert(vim.lsp.is_enabled(server), server .. " is not enabled")
    assert(config.cmd and config.filetypes, server .. " is missing upstream defaults")
    assert(config.capabilities.textDocument.completion, server .. " is missing real completion capabilities")
  end
  assert(#require("mason-lspconfig.settings").current.ensure_installed == 0, "Integration unexpectedly requests server downloads")
  assert(type(require("cmp_buffer").new) == "function", "Buffer completion provider is unavailable")
  for _, command in ipairs({ "stylua", "isort", "prettier", "rubocop" }) do
    assert(vim.fn.executable(command) == 1, command .. " executable is missing")
  end
  assert(#startup_errors == 0, "Plugin startup errors: " .. vim.inspect(startup_errors))
  print("Pinned Neovim startup, actual LSP defaults, and completion providers passed.")
end, debug.traceback)

if not success then
  io.stderr:write(tostring(failure) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
