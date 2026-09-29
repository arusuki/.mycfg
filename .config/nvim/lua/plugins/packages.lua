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
        ensure_installed = { "ruff", "pyright", "marksman"},
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
        handlers = {
          ["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
            if result and result.uri then
              local path = vim.uri_to_fname(result.uri)
              path = vim.fs.normalize(vim.uv.fs_realpath(path) or path)
              local cwd = vim.fn.getcwd()
              cwd = vim.fs.normalize(vim.uv.fs_realpath(cwd) or cwd)
              local prefix = cwd:gsub("/+$", "") .. "/"

              -- Keep library navigation/completion, but only show local diagnostics.
              if path:sub(1, #prefix) ~= prefix
                or path:find("/site-packages/", 1, true)
                or path:find("/dist-packages/", 1, true)
              then
                -- Publish an empty list to also clear any previous diagnostics.
                result.diagnostics = {}
              end
            end
            vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
          end,
        },
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              diagnosticMode = "openFilesOnly",
            },
            pythonPath=pythonPath,
          },
        },
        before_init = function(_, config)
          if config.settings.python.pythonPath == "python" then
            local pythonPath = require("util").get_var("pythonPath")
            if pythonPath == nil then
              return
            end
            config.settings.python.pythonPath = pythonPath[1]
          end
        end,
      })
      vim.lsp.config('ruff', {})
      vim.lsp.config('gopls', {})
      vim.lsp.config('ts_ls', {})
      vim.lsp.config('marksman', {})
      vim.lsp.config('clangd', {cmd={"clangd", "--completion-style=detailed", "-header-insertion=never"}})

      vim.keymap.set("n", "gh", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
      vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, {})
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {})
    end,
  },
}

