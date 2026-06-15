return {
  "numToStr/Comment.nvim",
  config = function()
    require("Comment").setup({
      -- Add options here if needed
    })
    
    -- Keymaps:
    -- gc - toggle comment (normal and visual)
    -- gcc - toggle comment on current line
    -- gbc - toggle block comment
  end,
  lazy = false,
}
