-- Keymaps configuration
local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set

-- Line movement with Alt+j and Alt+k (normal mode)
keymap("n", "<A-j>", ":m+1<CR>==", opts)
keymap("n", "<A-k>", ":m-2<CR>==", opts)

-- Line movement with Alt+j and Alt+k (visual mode)
keymap("v", "<A-j>", ":m'>+1<CR>gv=gv", opts)
keymap("v", "<A-k>", ":m'<-2<CR>gv=gv", opts)

-- Quick save and quit
keymap("n", "<leader>w", ":w<CR>", opts)
keymap("n", "<leader>q", ":q<CR>", opts)

-- Better navigation
keymap("n", "j", "gj", opts)  -- wrap-aware down
keymap("n", "k", "gk", opts)  -- wrap-aware up
