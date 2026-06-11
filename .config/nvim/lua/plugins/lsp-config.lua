return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    opts = {
      auto_install = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local lspconfig = require("lspconfig")
      lspconfig.ts_ls.setup({
        capabilities = capabilities
      })
      lspconfig.solargraph.setup({
        capabilities = capabilities
      })
      lspconfig.html.setup({
        capabilities = capabilities
      })
      lspconfig.lua_ls.setup({
        capabilities = capabilities
      })

      local opts = { noremap = true, silent = true }
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
      vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)

    end
  }
}
