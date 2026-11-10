return {
  "arusuki/compile-mode.nvim",
  branch = "main",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>xc", "<cmd>Compile<cr>", desc = "Compile: enter command" },
    { "<leader>xr", "<cmd>Recompile<cr>", desc = "Compile: rerun command" },
    { "<leader>xn", "<cmd>NextError<cr>", desc = "Compile: next error" },
    { "<leader>xp", "<cmd>PrevError<cr>", desc = "Compile: previous error" },
  },
  config = function()
    vim.g.compile_mode = {
      input_word_completion = true,
      use_pseudo_terminal = true,
    }
  end,
}
