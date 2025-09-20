vim.g.mapleader = " "

require("config.lazy")
require("config.vim-opts")

local home_dir = vim.loop.os_homedir()
vim.g.python3_host_prog = home_dir .. "/.local/share/mise/shims/python"
