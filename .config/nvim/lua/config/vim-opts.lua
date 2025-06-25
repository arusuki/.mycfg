vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.background = "light"
vim.opt.swapfile = false

-- Navigate vim panes better
vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')

vim.keymap.set('n', 'X', ":resize +5<CR>")
vim.keymap.set('n', 'S', ":resize -5<CR>")
vim.keymap.set('n', '<Esc>', "<Esc>:nohlsearch<CR>")
vim.keymap.set('n', '#', '#N')
vim.keymap.set('n', '*', '*N')
vim.keymap.set('n', '<CR>', 'i<CR><Esc>')

vim.keymap.set('t', '<C-q>', '<C-\\><C-n>')

vim.keymap.set('n', '<leader>l', ':lua vim.wo.relativenumber=not vim.wo.relativenumber<CR>')
vim.keymap.set('n', '<leader>t', ":execute \"belowright \" .. (&lines / 3) .. \"split +terminal\"<CR>")
vim.keymap.set('n', '<leader>sp', ":split<CR>")
vim.keymap.set('n', '<leader>gf', ":above split<CR>gf")
vim.keymap.set('n', '<leader>se', ":lua vim.diagnostic.open_float(0, {scope=\"line\", source=true})<CR>")

vim.keymap.set('n', '<c-X>', function()
                vim.wo.winfixheight=false
                vim.cmd.resize(99999)
              end
              )
vim.keymap.set('n', '<leader>]', function() vim.diagnostic.jump {count=1, float=true, wrap=true  } end)
vim.keymap.set('n', '<leader>[', function() vim.diagnostic.jump {count=-1, float=true, wrap=true } end)

vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight_yank', {}),
  desc = 'Hightlight selection on yank',
  pattern = '*',
  callback = function()
    vim.highlight.on_yank { higroup = 'IncSearch', timeout = 150 }
  end,
})

terminal_group = vim.api.nvim_create_augroup('terminal_event', {})

vim.api.nvim_create_autocmd('WinEnter', {
  group = terminal_group,
  desc = 'automatic change terminal size when enter',
  pattern = 'term://*',
  callback = function()
    vim.cmd.resize(math.floor(vim.o.lines/3))
  end,
})

vim.api.nvim_create_autocmd('WinLeave', {
  group = terminal_group,
  desc = 'automatic change terminal size when leaving',
  pattern = 'term://*',
  callback = function()
    vim.cmd.resize(0)
    vim.wo.winfixheight = true
  end,
})

vim.wo.number = true
vim.wo.relativenumber=true

vim.diagnostic.config({
  virtual_text = true,
})
