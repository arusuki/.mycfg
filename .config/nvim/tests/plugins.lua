-- Run from .config/nvim: nvim --clean -l tests/plugins.lua
local config_root = vim.fn.getcwd()
vim.opt.rtp:prepend(config_root)
vim.fn.mkdir(vim.fn.stdpath("data"), "p")
local plugin_root = vim.env.MYCFG_TEST_PLUGIN_DIR or (vim.fn.stdpath("data") .. "/lazy")
for _, name in ipairs({
  "nvim-cmp", "LuaSnip", "cmp-nvim-lsp", "nvim-lspconfig", "scope.nvim",
  "nvim-dap", "nvim-dap-python", "harpoon", "plenary.nvim",
}) do
  vim.opt.rtp:append(plugin_root .. "/" .. name)
end
vim.g.mapleader = " "

local function setup(module, name)
  for _, spec in ipairs(require(module)) do
    if spec[1] == name then
      spec.config(spec, spec.opts)
      return
    end
  end
  error("Plugin spec missing: " .. name)
end

setup("plugins.packages", "neovim/nvim-lspconfig")
for _, name in ipairs({ "pyright", "ruff", "gopls", "ts_ls", "marksman", "clangd" }) do
  assert(vim.lsp.config[name].capabilities.textDocument.completion.completionItem.snippetSupport,
    name .. " must inherit cmp capabilities")
end
assert(package.loaded.lspconfig == nil, "the deprecated lspconfig entry point must not be loaded")
assert(#vim.lsp.get_clients() == 0, "configuring servers must not start them")

setup("plugins.completion", "hrsh7th/nvim-cmp")
require("config.insert-ops") -- Same order as init.lua.
local cmp = require("cmp")
local mappings = cmp.get_config().mapping
local normalize = require("cmp.utils.keymap").normalize
for _, key in ipairs({ "<C-b>", "<C-f>", "<C-e>" }) do
  assert(mappings[normalize(key)] == nil, "cmp must not override Insert movement: " .. key)
  assert(vim.fn.maparg(key, "i") ~= "", "Insert movement must remain available: " .. key)
end
for _, key in ipairs({ "<C-PageUp>", "<C-PageDown>", "<M-e>", "<C-y>" }) do
  assert(mappings[normalize(key)], "completion action must have its own mapping: " .. key)
end

-- Exercise real InsertEnter handling and keypresses with an actual completion menu.
cmp.register_source("mycfg_test", {
  complete = function(_, _, callback)
    callback({ { label = "abcdef", documentation = "test documentation" } })
  end,
})
cmp.setup.buffer({ sources = { { name = "mycfg_test" } } })
local menu_opened = false
vim.keymap.set("i", "<F5>", function()
  cmp.complete()
  menu_opened = vim.wait(1000, cmp.visible, 10)
end, { buffer = true })
local keys = vim.api.nvim_replace_termcodes("iabc<F5><C-b>X<C-f>Y<C-e>Z<Esc>", true, false, true)
vim.api.nvim_feedkeys(keys, "xt", false)
assert(menu_opened, "the completion menu must actually open before testing movement")
assert(vim.api.nvim_get_current_line() == "abXcYZ", "cmp must preserve Insert movement with its menu open")
vim.bo.modified = false
vim.cmd("enew")

setup("plugins.debug", "mfussenegger/nvim-dap-python")
local dap_python, dap = require("dap-python"), require("dap")
assert(dap_python.test_runner() == "pytest", "pytest must be the default runner")
require("util").set_var("python_test_runner", { "# comment", "unittest" })
assert(dap_python.test_runner() == "unittest", "EditVar runner changes must apply to the next test")
local executable, notify = vim.fn.executable, vim.notify
local warnings = {}
vim.fn.executable = function(cmd)
  return cmd == "debugpy-adapter" and 0 or executable(cmd)
end
vim.notify = function(message) warnings[#warnings + 1] = message end
for _, name in ipairs({ "python", "debugpy" }) do
  dap.adapters[name](function() error("missing adapter must not launch") end, { request = "launch" })
end
assert(#warnings == 2 and warnings[1]:find("debugpy-adapter not found", 1, true), "missing adapter must explain how to install")
local resolved
dap.adapters.python(function(adapter) resolved = adapter end, { request = "attach", connect = { port = 5678 } })
assert(resolved and resolved.type == "server", "remote attach must work without a local debugpy adapter")
vim.fn.executable = function(cmd) return cmd == "debugpy-adapter" and 1 or executable(cmd) end
dap.adapters.python(function(adapter) resolved = adapter end, { request = "launch" })
assert(resolved.type == "executable" and resolved.command == "debugpy-adapter", "installation must allow retry without reloading")
vim.fn.executable, vim.notify = executable, notify

-- Isolate Harpoon persistence from the user's lists.
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")
vim.cmd.cd(temp)
setup("plugins.editor", "ThePrimeagen/harpoon")
local harpoon = require("harpoon")
local list = harpoon:list("file_with_line")
local path = temp .. "/space % # | literal.txt"
vim.fn.writefile({ "first", "second", "third" }, path)
vim.api.nvim_set_current_buf(vim.fn.bufadd(path))
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.fn.maparg("<leader>ma", "n", false, true).callback()
assert(list:get(1).context.file_path == path and list:get(1).context.line_number == 3,
  "the add mapping must store file and line in the named list")
vim.cmd("enew")
list:select(1)
assert(vim.api.nvim_buf_get_name(0) == path and vim.fn.line(".") == 3,
  "selection must open literal special characters and restore the line")
vim.api.nvim_buf_set_lines(0, 1, -1, true, {})
vim.bo.modified = false
vim.cmd("enew")
list:select(1)
assert(vim.fn.line(".") == 1, "a shortened file must clamp the saved line")
list:clear()
vim.cmd.cd(config_root)
vim.fn.delete(temp, "rf")
print("PASS: LSP capabilities, completion mappings, Python DAP, Harpoon file and line")
