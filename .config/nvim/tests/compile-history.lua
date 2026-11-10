-- Run from .config/nvim: nvim --clean -i NONE -l tests/compile-history.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local plugin_root = vim.env.MYCFG_TEST_PLUGIN_DIR or (vim.fn.stdpath("data") .. "/lazy")
for _, name in ipairs({ "compile-mode.nvim", "plenary.nvim" }) do
  vim.opt.rtp:append(plugin_root .. "/" .. name)
end
require("plugins.compile-mode").config()
vim.cmd("runtime plugin/completion.vim")
local compile = require("compile-mode")

local snapshots
vim.keymap.set("c", "<F5>", function()
  snapshots[#snapshots + 1] = vim.fn.getcmdline()
  return ""
end, { expr = true })

local function check(history, command, keys, expected, prompt)
  vim.fn.histdel("input")
  for _, entry in ipairs(history) do
    vim.fn.histadd("input", entry)
  end
  vim.g.compile_command = command
  snapshots = {}
  vim.api.nvim_feedkeys(vim.keycode(keys .. "<C-c>"), "t", false)
  if prompt then
    vim.ui.input({ prompt = prompt, default = command }, function() end)
  else
    compile.compile()
  end
  assert(vim.deep_equal(snapshots, expected), vim.inspect({ expected = expected, actual = snapshots }))
  assert(vim.g.compile_command == command, "cancelling must keep the last compile command")
end

local history = { "echo oldest", "echo older", "echo latest" }
check(history, "echo latest", "<F5><C-p><F5><C-p><F5><C-n><F5><C-n><F5><C-p><F5>", {
  "echo latest", "echo older", "echo oldest", "echo older", "echo latest", "echo older",
})
-- Editing the default starts a new draft; the latest entry must remain reachable.
check(history, "echo latest", " edited<F5><C-p><F5><C-n><F5>", {
  "echo latest edited", "echo latest", "echo latest edited",
})
-- Direct :Compile commands may differ from the newest input() history entry.
check(history, "echo direct", "<F5><C-p><F5>", { "echo direct", "echo latest" })
check({}, "echo latest", "<F5><C-p><F5>", { "echo latest", "echo latest" })
check({ "echo latest" }, "echo latest", "<F5><C-p><F5>", { "echo latest", "echo latest" })
check(history, "echo latest", "<F5><C-p><F5><C-p><F5>", {
  "echo latest", "echo latest", "echo older",
}, "Another prompt: ")
print("PASS: compile history navigation, edited drafts, cancellation and other prompts")
