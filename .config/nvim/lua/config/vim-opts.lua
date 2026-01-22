vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.background = "light"
vim.go.showtabline = 0
vim.opt.swapfile = false

-- Navigate vim panes better
-- vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
-- vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
-- vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
-- vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')

vim.keymap.set('n', 'X', ":resize +5<CR>")
vim.keymap.set('n', 'S', ":resize -5<CR>")
vim.keymap.set('n', 'Q', ":bd<CR>")
vim.keymap.set('n', '<Esc>', "<Esc>:nohlsearch<CR>")
vim.keymap.set('n', '#', '#N')
vim.keymap.set('n', '*', '*N')
vim.keymap.set('n', '<C-P>', 'i<CR><Esc>0k')
vim.keymap.set('n', '<C-N>', 'i<CR><Esc>')

vim.keymap.set('t', '<C-q>', '<C-\\><C-n>')

vim.keymap.set('n', '<leader>r', ':lua vim.wo.relativenumber=not vim.wo.relativenumber<CR>')
vim.keymap.set('n', '<leader>t', ":execute \"belowright \" .. (&lines / 3) .. \"split +terminal\"<CR>:lua vim.wo.winfixheight=true<CR>:execute clearmatches()<CR>")
vim.keymap.set('n', '<leader>sp', ":split | wincmd j<CR>")
vim.keymap.set('n', '<leader>vp', ":vsplit | wincmd l<CR>")
vim.keymap.set('n', '<leader>gf', ":above split<CR>gf")
vim.keymap.set('n', '<leader>gF', ":above split<CR>gF")
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

local function is_top_level_window()
  local layout = vim.fn.winlayout()
  local cur_win = vim.fn.win_getid()

  if layout[1] == "col" then
    return false
  end
  if layout[1] == "leaf" then
    return layout[2] == cur_win
  end
  for _, child in ipairs(layout[2]) do
    if child[1] == "leaf" and child[2] == cur_win then
      return true
    end
  end
  return false
end

vim.api.nvim_create_autocmd('WinEnter', {
  group = terminal_group,
  desc = 'automatic change terminal size when enter',
  pattern = 'term://*',
  callback = function()
    if is_top_level_window() then
      vim.wo.winfixheight = false
    -- else
    --   vim.cmd.resize(math.floor(vim.o.lines/3))
    end
  end,
})
--
-- vim.api.nvim_create_autocmd('WinLeave', {
--   group = terminal_group,
--   desc = 'automatic change terminal size when leaving',
--   pattern = 'term://*',
--   callback = function()
--     if not is_top_level_window() then
--       vim.cmd.resize(1)
--     end
--     vim.wo.winfixheight = true
--   end,
-- })

vim.wo.number = true
vim.wo.relativenumber=true

vim.o.sessionoptions="blank,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

local function toggle_diag_virtual_text()
  local v = vim.diagnostic.config().virtual_text
  vim.diagnostic.config({ virtual_text = not v })
end
vim.keymap.set('n', '<leader>l', toggle_diag_virtual_text)

vim.o.autoread = true

local function visual_goto_file()
  local selected = require("util").get_visual_selected_text('')
  local path = vim.fn.fnameescape(selected)

  vim.notify("enter path: " .. path)
  vim.cmd("split | e " .. path)
end

vim.keymap.set('v', "<leader>gF", visual_goto_file)

vim.g.clipboard = "osc52"

local show_signcolumn = true

local function toggle_signcolumn()
  if show_signcolumn then
    vim.opt.signcolumn = "no"
  else
    vim.opt.signcolumn = "auto"
  end
  show_signcolumn = not show_signcolumn
end

vim.opt.signcolumn = "no"
vim.keymap.set('n', '<leader>os', toggle_signcolumn)

for i = 1, 8 do
  local lhs = "<leader>" .. i
  local rhs = i .. "<c-w>w"
  vim.keymap.set("n", lhs, rhs, { desc = "Move to window " .. i })

  lhs = "<leader><leader>" .. i
  local rhs = i .. "gt"
  vim.keymap.set("n", lhs, rhs, { desc = "Move to tab " .. i })
end

local maxmise_windows = function()
  require("util").close_all_other_windows({
    -- "filesystem", -- neo-tree
    "Trouble",
    -- "term",
  })
end

vim.keymap.set("n", "<leader>wo", maxmise_windows)


local trailingWhitespaceGroup = vim.api.nvim_create_augroup('TrailingWhitespace', { clear = true })

local ignored_buftypes = {terminal = true, nofile = true }

local ignored_filetypes = {
  ['neo-tree'] = true,
  Trouble = true,
  trouble = true,
}

vim.api.nvim_create_autocmd(
  { 'ColorScheme', 'BufWinEnter', 'WinEnter' },
  {
    group = trailingWhitespaceGroup,
    pattern = '*',
    callback = function()
      local buftype = vim.bo.buftype
      local filetype = vim.bo.filetype
      if ignored_buftypes[buftype] or ignored_filetypes[filetype] then
        if vim.w.trailing_whitespace_match_id then
          pcall(vim.fn.matchdelete, vim.w.trailing_whitespace_match_id, vim.api.nvim_get_current_win())
          vim.w.trailing_whitespace_match_id = nil
        end
        return
      end
      if vim.w.trailing_whitespace_match_id then
        return
      end
      vim.w.trailing_whitespace_match_id = vim.fn.matchadd('TrailingWhitespace', '\\s\\+$')
    end,
  }
)

-- setup tree-sitter based fold
vim.opt_local.foldmethod = 'expr'
vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.go.foldlevelstart = 99

-- line wrap
vim.opt.linebreak = true
vim.opt.showbreak = '↪ '

-- "compilation mode"

local function get_visible_bufs_set()
  local visible_bufs = {}
  local wins = vim.api.nvim_list_wins()
  for _, win_id in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win_id) then
      local buf_id = vim.api.nvim_win_get_buf(win_id)
      if vim.api.nvim_buf_is_valid(buf_id) then
        visible_bufs[buf_id] = true
      end
    end
  end
  return visible_bufs
end

local function focus_mru_terminal_optimized()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local mru_terminal_bufnr = nil
  local max_lastused = -1
  local visible_bufs = get_visible_bufs_set()

  for _, buf in ipairs(bufs) do
    if vim.bo[buf.bufnr].buftype == 'terminal' and visible_bufs[buf.bufnr] == nil then
      if buf.lastused > max_lastused then
        max_lastused = buf.lastused
        mru_terminal_bufnr = buf.bufnr
      end
    end
  end
  if mru_terminal_bufnr then
    vim.cmd('buffer ' .. mru_terminal_bufnr)
  else
    print("No terminal found. Opening a new one.")
    vim.cmd('belowright split | terminal')
  end
  vim.api.nvim_feedkeys("a", "a", false)
end

vim.keymap.set('n', '<leader>cm', focus_mru_terminal_optimized)
vim.keymap.set('n', '<leader>cc', '<Cmd>b#<CR>')
