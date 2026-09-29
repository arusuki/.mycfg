-- Run: nvim --clean -l tests/tab-lsp.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/scope.nvim")
require("scope").setup({})
vim.o.hidden = true

local function check(value, message)
  assert(value, message)
end
local function settle()
  vim.wait(100, function() return false end, 5)
end

local launches = 0
local initialize_delay = 0
local function server(dispatchers)
  launches = launches + 1
  local closing, request_id = false, 0
  return {
    request = function(method, _, callback)
      request_id = request_id + 1
      local result = method == "initialize" and { capabilities = { textDocumentSync = 1 } } or nil
      vim.defer_fn(function() callback(nil, result) end, method == "initialize" and initialize_delay or 0)
      return true, request_id
    end,
    notify = function(method)
      if method == "exit" then
        closing = true
        dispatchers.on_exit(0, 0)
      end
      return true
    end,
    is_closing = function() return closing end,
    terminate = function()
      closing = true
      dispatchers.on_exit(0, 0)
    end,
  }
end

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/one/.git", "p")
vim.fn.mkdir(root .. "/two/.git", "p")
vim.lsp.config("tab_test", { cmd = server, filetypes = { "tab_test" }, root_markers = { ".git" } })
local late_root
vim.lsp.config("tab_async", {
  cmd = server,
  filetypes = { "tab_test" },
  root_dir = function(_, callback) late_root = callback end,
})
require("config.tab-lsp").setup({ "tab_test" })

local function edit(path)
  vim.cmd.edit(vim.fn.fnameescape(root .. path))
  vim.bo.filetype = "tab_test"
  settle()
  return vim.api.nvim_get_current_buf()
end
local function attached(buf)
  return vim.lsp.get_clients({ bufnr = buf, name = "tab_test" })
end

local first_tab = vim.api.nvim_get_current_tabpage()
local a = edit("/one/a.txt")
check(#attached(a) == 0 and launches == 0, "LSP must default off")
vim.cmd("lsp enable tab_test")
settle()
check(#attached(a) == 1, "native enable must attach")
local id = attached(a)[1].id
check(attached(a)[1].root_dir == root .. "/one", "project root must be preserved")

local hidden = edit("/one/hidden.txt")
check(attached(hidden)[1].id == id, "new buffers in an enabled tab must reuse its client")
vim.cmd("tabnew")
local second_tab = vim.api.nvim_get_current_tabpage()
local b = edit("/one/b.txt")
check(#attached(b) == 0, "new tab must default off even for same root")
check(#attached(a) == 1 and #attached(hidden) == 1, "background tab must stay attached")
vim.cmd("lsp enable tab_test")
settle()
check(attached(b)[1].id == id and launches == 1, "enabled tabs must share the project client")
vim.cmd("lsp disable tab_test")
check(#attached(b) == 0 and #attached(a) == 1, "disable must affect only current tab")
check(not vim.lsp.get_client_by_id(id):is_stopped(), "disable must not stop the shared process")

vim.cmd.buffer(a)
settle()
check(#attached(a) == 0, "shared buffer must follow the disabled current tab")
vim.api.nvim_set_current_tabpage(first_tab)
settle()
check(attached(a)[1].id == id, "returning to enabled tab must reattach shared buffer")
vim.api.nvim_set_current_tabpage(second_tab)
settle()
check(#attached(a) == 0, "returning to disabled tab must detach again")

vim.cmd("tabnew")
local c = edit("/two/c.txt")
vim.cmd("lsp enable")
settle()
check(#attached(c) == 1 and attached(c)[1].id ~= id, "different roots must use separate clients")
local completions = require("vim._core.ex_cmd").lsp_complete("lsp disable ")
check(vim.tbl_contains(completions, "tab_test"), "disable completion must use current tab state")
vim.cmd("lsp disable")
check(#attached(c) == 0, "argument-free disable must clear the current tab")
check(#attached(hidden) == 1, "other tab hidden buffers must stay attached")

vim.cmd("lsp enable tab_async")
check(late_root ~= nil, "async root resolver must run")
vim.cmd("lsp disable tab_async")
late_root(root .. "/two")
settle()
check(#vim.lsp.get_clients({ bufnr = c }) == 0, "late root callback must not reenable a disabled tab")

vim.cmd("lsp enable tab_test")
vim.cmd("tabclose")
settle()
check(#attached(c) == 0, "closing a tab must detach its documents")
check(#attached(hidden) == 1, "closing a tab must preserve other tabs")

vim.api.nvim_set_current_tabpage(first_tab)
settle()
vim.bo[hidden].filetype = "text"
settle()
check(#attached(hidden) == 0, "changing to an unsupported filetype must detach")
vim.cmd("lsp disable")
check(#attached(a) == 0, "disable must also detach hidden buffers")

-- Disable after the process starts but before the initialize reply arrives.
initialize_delay = 150
vim.lsp.config("tab_slow", { cmd = server, filetypes = { "tab_test" }, root_markers = { ".git" } })
vim.cmd.buffer(a)
settle()
vim.cmd("lsp enable tab_slow")
vim.wait(30, function() return false end, 5)
vim.cmd("lsp disable tab_slow")
vim.wait(200, function() return false end, 5)
check(#vim.lsp.get_clients({ bufnr = a }) == 0, "late initialization must not reattach disabled buffers")

for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
vim.fn.delete(root, "rf")
print("PASS: tab defaults, commands, scope membership, client reuse, shared buffers, async roots, cleanup")
