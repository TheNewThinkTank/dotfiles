return {
  require("plugins.catppuccin"),  -- Load first with priority
  require("plugins.alpha"),
  require("plugins.completions"),
  require("plugins.lsp-config"),
  require("plugins.lualine"),
  require("plugins.neo-tree"),
  require("plugins.none-ls"),
  require("plugins.telescope"),
  require("plugins.treesitter"),
  require("plugins.vim-surround"),
  require("plugins.comment"),
  require("plugins.vim-tmux-navigator"),
}
