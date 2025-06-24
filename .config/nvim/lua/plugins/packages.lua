return {
  {
    "mason-org/mason.nvim",
    opts = {}
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    opts = {},
    dependencies = {
      "neovim/nvim-lspconfig",
    },
    config = function()
      require("mason-lspconfig").setup {
        automatic_enable = false,
        ensure_installed = { "ruff", "pyright"},
      }
    end
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require("lspconfig")
      local pythonPath = os.getenv("PY") or "python"

      vim.lsp.config('pyright', {
        -- Server-specific settings. See `:help lsp-quickstart`
        settings = {
          python = {
            pythonPath=pythonPath,
          },
        },
        before_init = function(_, config)
          if config.settings.python.pythonPath == "python" then
            config.settings.python.pythonPath = require("util").get_var("pythonPath")[1]
          end
        end,
      })
      vim.lsp.config('ruff', {})

      vim.keymap.set("n", "gh", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
    end,
  },
}

