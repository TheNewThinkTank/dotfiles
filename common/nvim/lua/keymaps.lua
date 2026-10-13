-- Keymaps configuration
local opts = { noremap = true, silent = true }
local keymap = vim.keymap.set

-- Line movement with Shift+Alt+j and Shift+Alt+k (normal mode)
keymap("n", "<A-S-j>", ":m+1<CR>==", opts)
keymap("n", "<A-S-k>", ":m-2<CR>==", opts)

-- Line movement with Shift+Alt+j and Shift+Alt+k (visual mode)
keymap("v", "<A-S-j>", ":m'>+1<CR>gv=gv", opts)
keymap("v", "<A-S-k>", ":m'<-2<CR>gv=gv", opts)

-- Quick save and quit
keymap("n", "<leader>w", ":w<CR>", opts)
keymap("n", "<leader>q", ":q<CR>", opts)

-- Better navigation
keymap("n", "j", "gj", opts)  -- wrap-aware down
keymap("n", "k", "gk", opts)  -- wrap-aware up
