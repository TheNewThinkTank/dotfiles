return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      integrations = {
        lualine = true,
      }
    })
    vim.cmd.colorscheme "catppuccin"
  end
}
