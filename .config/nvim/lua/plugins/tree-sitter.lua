return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      local ensure_installed = {"lua", "python", "c", "cpp", "cuda", "markdown"}

      ts.install {"lua", "python", "c", "cpp", "cuda", "markdown"}

      vim.api.nvim_create_autocmd('FileType', {
        pattern = ensure_installed,
        callback = function()
          -- Highlighting
          vim.treesitter.start()
          -- Folds
          vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
          vim.wo[0][0].foldmethod = 'expr'
          -- Indentation
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
    enabled = true,
  },
}
