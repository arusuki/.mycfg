return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    branch = "main",
    config = function()
      local ts = require("nvim-treesitter")
      local ensure_installed = require("config.code-filetypes")

      ts.install(ensure_installed)

      vim.api.nvim_create_autocmd('FileType', {
        pattern = ensure_installed,
        callback = function()
          vim.treesitter.start()
          vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.wo[0][0].foldmethod = 'expr'
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

    end,
    enabled = true,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    config = function()
      require'treesitter-context'.setup {
        mode = 'cursor',
        separator = nil,
        zindex = 20,
        on_attach = nil,
        multiline_threshold = 3,
    }
    vim.keymap.set("n", "<leader>ct", "<CMD>TSContext toggle<CR>", { desc = "Toggle treesitter context" })
    end,
    enabled = true,
  },
  {
    "sustech-data/wildfire.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("wildfire").setup(
        {
          surrounds = {
              { "(", ")" },
              { "{", "}" },
              { "<", ">" },
              { "[", "]" },
          },
          keymaps = {
              init_selection = "<CR>",
              node_incremental = "<CR>",
              node_decremental = "<BS>",
          },
          filetype_exclude = { "qf" },
      }
      )
    end,
  }
}
