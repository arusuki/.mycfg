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


return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      vim.keymap.set('n', '<leader>co', require'dap'.continue)
      vim.keymap.set('n', '<leader>b', require'dap'.toggle_breakpoint)
      vim.keymap.set('n', '<leader>i', require'dap'.step_into)
    end
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    keys = {
      {"<leader>sdp", "<cmd>lua require('dap-python').test_method({config={justMyCode=false}})<CR>"},
    },
    config = function()
      local util = require("util")
      local dap_python = require("dap-python")
      if util.get_var("python_test_runner") == nil then
        util.set_var("python_test_runner", { "pytest" })
      end
      dap_python.resolve_python = resolve_python
      -- Read on every test run so :EditVar takes effect without reloading.
      dap_python.test_runner = function()
        return (util.get_var("python_test_runner") or {})[1] or "pytest"
      end
      dap_python.setup("debugpy-adapter")

      local dap = require("dap")
      local python_adapter = dap.adapters.python
      dap.adapters.python = function(callback, config)
        if config.request ~= "attach" and vim.fn.executable("debugpy-adapter") == 0 then
          vim.notify(
            "Python DAP unavailable: debugpy-adapter not found. Install with :MasonInstall debugpy "
              .. "or uv tool install debugpy, then ensure debugpy-adapter is on PATH.",
            vim.log.levels.ERROR
          )
          return
        end
        python_adapter(callback, config)
      end
      dap.adapters.debugpy = dap.adapters.python
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
