return {
  { "tiagovla/scope.nvim",
    config = function()
      require("scope").setup({
        hooks = {
            post_tab_enter = function()
              local ok, ts_context = pcall(require, "treesitter-context")
              if ok then
                  ts_context.enable()
              end
            end,
        },
      })
    end,
    enabled = true
  },
}
