local function resolve_python()
  local env = os.getenv("PY")
  if env ~= nil then
    return env
  end
  local pythonPath = require("util").get_var("pythonPath")
  if pythonPath == nil then
    return nil
  end
  return pythonPath[1]
end

-- local function test_runner()
--
-- end

return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      vim.keymap.set('n', '<leader>co', require'dap'.continue)
      vim.keymap.set('n', '<leader>b', require'dap'.toggle_breakpoint)
      vim.keymap.set('n', '<leader>i', require'dap'.step_into)
      vim.keymap.set('n', '<c-i>', require'dap'.step_over)
    end
  },
  {
    "mfussenegger/nvim-dap-python",
    keys = {
      {"<leader>sdp", "<cmd>lua require('dap-python').test_method({config={justMyCode=false}})<CR>"},
    },
    config = function()
      require'util'.set_var("python_test_runner", {"pytest"})
      require'dap-python'.resolve_python = resolve_python
      require'dap-python'.test_runner = test_runner
      require'dap-python'.setup("debugpy-adapter")
    end
  },
  {
      "igorlfs/nvim-dap-view",
      ---@module 'dap-view'
      ---@type dapview.Config
      opts = {},
    config = function()
      vim.keymap.set('n', '<leader>od', ":DapViewToggle<CR>")
    end
  },
}
