return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "catppuccin/nvim" },
  config = function()
    require('lualine').setup({
      options = {
        theme = 'catppuccin'  -- matches catppuccin colorscheme
      }
    })
  end
}
