-- Indentation / tabbing
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

-- Leader key
vim.g.mapleader = " "

-- Display settings
vim.opt.number = true           -- line numbers
vim.opt.relativenumber = true   -- relative line numbers
vim.opt.cursorline = true       -- highlight current line

-- Search settings
vim.opt.hlsearch = false        -- don't highlight all search matches
vim.opt.incsearch = true        -- show matches while typing
vim.opt.ignorecase = true       -- ignore case in searches
vim.opt.smartcase = true        -- unless you use uppercase

-- UI improvements
vim.opt.mouse = "a"             -- enable mouse support
vim.opt.scrolloff = 5           -- keep 5 lines visible when scrolling
vim.opt.sidescroll = 5
vim.opt.ruler = true

-- Spell checking
vim.opt.spell = true
vim.opt.spelllang = "en_us"

-- File backup and undo
local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
end
ensure_dir(vim.fn.expand("~/.vim/backup"))
ensure_dir(vim.fn.expand("~/.vim/swaps"))
ensure_dir(vim.fn.expand("~/.vim/undo"))

vim.opt.backup = true
vim.opt.backupdir = vim.fn.expand("~/.vim/backup//")
vim.opt.swapfile = true
vim.opt.directory = vim.fn.expand("~/.vim/swaps//")
vim.opt.undofile = true         -- persistent undo history
vim.opt.undodir = vim.fn.expand("~/.vim/undo//")

-- UI behavior
vim.opt.errorbells = false
vim.opt.visualbell = false
