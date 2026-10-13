local servers = { "ts_ls", "solargraph", "html", "lua_ls" }

return {
  {
    "mason-org/mason.nvim",
    version = "v2.3.1",
    lazy = false,
    config = function()
      require("mason").setup()
    end
  },
  {
    "mason-org/mason-lspconfig.nvim",
    version = "v2.3.0",
    lazy = false,
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = {
      ensure_installed = servers,
      automatic_enable = servers,
    },
  },
  {
    "neovim/nvim-lspconfig",
    version = "v2.12.0",
    lazy = false,
    dependencies = {
      "mason-org/mason.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.enable(servers)

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
