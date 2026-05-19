local opts = { silent = true }

vim.keymap.set("i", "<C-a>", "<C-o>0", opts)
vim.keymap.set("i", "<C-e>", "<C-o>$", opts)
vim.keymap.set("i", "<C-b>", "<C-g>U<Left>", opts)
vim.keymap.set("i", "<C-f>", "<C-g>U<Right>", opts)

vim.keymap.set("i", "<M-f>", "<C-o>w", opts)
vim.keymap.set("i", "<M-b>", "<C-o>b", opts)
