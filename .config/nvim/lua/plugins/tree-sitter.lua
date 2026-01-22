return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- tag = "v0.10.0",
    -- build = ":TSUpdate",
    config = function()
      -- ts = require("nvim-treesitter.configs")
      -- ts.setup({
      --   ensure_installed = {"lua", "python", "c", "cpp", "cuda", "markdown"},
      --   auto_install = true,
      --   highlight = { enable = true },
      --   indent = { enable = true },
      -- })
      --
      ts = require("nvim-treesitter")

      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'python' },
        callback = function() vim.treesitter.start() end,
      })

      -- ts.install {"lua", "python", "c", "cpp", "cuda", "markdown"}
    end,
    -- enabled = false,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    config = function()
      require'treesitter-context'.setup {
        mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
        -- Separator between context and content. Should be a single character string, like '-'.
        -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
        separator = nil,
        zindex = 20, -- The Z-index of the context window
        on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
        multiline_threshold = 3,
    }
    vim.keymap.set("n", "<leader>ct", "<CMD>TSContext toggle<CR>", { desc = "Toggle treesitter context" })
    end,
    enabled = false,
  },
}
