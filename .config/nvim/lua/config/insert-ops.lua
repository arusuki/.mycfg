local opts = { silent = true }

vim.keymap.set("i", "<C-a>", "<C-o>0", opts)
vim.keymap.set("i", "<C-e>", "<C-o>$", opts)
vim.keymap.set("i", "<C-b>", "<C-g>U<Left>", opts)
vim.keymap.set("i", "<C-f>", "<C-g>U<Right>", opts)
vim.keymap.set("i", "<C-d>", "<Del>", opts)

vim.keymap.set("i", "<M-f>", "<C-o>w", opts)
vim.keymap.set("i", "<M-b>", "<C-o>b", opts)
vim.keymap.set("i", "<M-d>", "<C-o>dw", opts)

-- Command-line and input() prompts use the same character movement keys.
-- This nonrecursive mapping preserves the original CTRL-F command-line window.
vim.keymap.set("c", "<C-x><C-e>", "<C-f>", { silent = true, desc = "Open command-line window" })
vim.keymap.set("c", "<C-b>", "<Left>", opts)
vim.keymap.set("c", "<C-f>", "<Right>", opts)
vim.keymap.set("c", "<M-b>", "<C-Left>", opts)
-- Leave command-line <M-f> to suggestions.nvim: accept a word or move forward.

-- Command-line <Del> deletes backwards at EOL; CTRL-D should do nothing there.
vim.keymap.set("c", "<C-d>", function()
  return vim.fn.getcmdpos() <= #vim.fn.getcmdline() and "<Del>" or ""
end, { expr = true, silent = true, desc = "Delete character forward" })

vim.keymap.set("c", "<M-d>", function()
  local line = vim.fn.getcmdline()
  local pos = vim.fn.getcmdpos()
  local word = line:sub(pos):match("^%s*%S+") or line:sub(pos)
  vim.fn.setcmdline(line:sub(1, pos - 1) .. line:sub(pos + #word), pos)
  return ""
end, { expr = true, silent = true, desc = "Delete word forward" })
