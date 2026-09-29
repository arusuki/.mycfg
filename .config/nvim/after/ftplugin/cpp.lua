-- Wait until a separator is typed before treating `name:` as a label.
-- Reindent before Enter so the label and the new line both get their indent.
for _, option in ipairs({ "indentkeys", "cinkeys" }) do
  vim.opt_local[option]:remove(":")
  vim.opt_local[option]:append("*<Return>")
end

vim.keymap.set("i", "<Space>", function()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  local label = before:match("^%s*[%a_][%w_]*:$")
  local case = before:match("^%s*case%s+.*[^:]:$")

  -- Ctrl-F invokes native reindent without remapping the user's Ctrl-F binding.
  local keys = (label or case) and "<C-f><Space>" or "<Space>"
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "in", false)
end, { buffer = true, desc = "Indent C++ label after a space" })

local undo = "setlocal indentkeys< cinkeys< | silent! iunmap <buffer> <Space>"
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
