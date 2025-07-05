local M = {}
local _vars = {}

M.vars = _vars

_buffers = {}

M.edit_var = function(opts)
  local var_name = opts.fargs[1]
  local content = _vars[var_name] or {}
  local buf = _buffers[var_name]
  if buf == nil then
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, "var://" .. var_name)
    vim.api.nvim_set_option_value("swapfile", false, {buf=buf})
    vim.api.nvim_set_option_value("bufhidden", "delete", {buf=buf})
    vim.api.nvim_set_option_value("commentstring", "# %s", {buf=buf})
    _buffers[var_name] = buf
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, content)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
  vim.wo.relativenumber = false
end

M.get_var = function(key)
  local val = _vars[key]
  if val == nil then
    return val
  end
  return vim.tbl_filter(function(v)
    return v ~= "" and not string.match(v, "^#") 
  end, val
  )
end

M.set_var = function(key, value)
  _vars[key] = value
end

M.get_visual_selected_text = function(line_delim)
  local startv = vim.fn.getpos("v")
  local endv = vim.fn.getpos(".")
  local start_line, start_col = startv[2], startv[3]
  local end_line, end_col = endv[2], endv[3]
  local lines = vim.fn.getline(start_line, end_line)

  if start_line == end_line then
    return string.sub(lines[1] or "", start_col, end_col)
  end
  lines[1] = string.sub(lines[1], start_col, -1)
  lines[#lines] = string.sub(lines[#lines], 0, end_col)
  return table.concat(lines, line_delim or "\n")
end

terminal_group = vim.api.nvim_create_augroup('util_values', {})
vim.api.nvim_create_autocmd('BufLeave', {
  group = terminal_group,
  desc = 'change utils.vars on leaf',
  pattern = 'var://*',
  callback = function()
    local bufname = vim.fn.bufname("%")
    local bufnr = vim.fn.bufnr("%")
    local var_name = string.match(bufname, "var://(.*)")
    vim.notify(string.format("setvars: %s", var_name))
    local cont = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    _vars[var_name] = cont
  end,
})

vim.api.nvim_create_autocmd('BufDelete', {
  group = terminal_group,
  desc = 'remove buffer from internal _buffers table on delete',
  pattern = 'var://*',
  callback = function()
    local bufname = vim.fn.bufname("%")
    _buffers[bufname] = nil
  end,
})


function completion(ArgLead, CmdLine, CursorPos)
  return vim.tbl_keys(_vars)
end

_G.UtilVarsCompletion = completion

vim.api.nvim_create_user_command('EditVar', M.edit_var, { desc = 'pass', nargs=1, complete = completion})
vim.keymap.set('n', '<leader>v', ":below split | resize 5 | set winfixheight | EditVar ", { desc = 'Telescope help tags' })
_vars.pythonPath = {"python"}

function clear_terminal()
  local scrollback = vim.bo.scrollback
  vim.bo.scrollback = 1
  local keys = vim.api.nvim_replace_termcodes("a<C-L><C-Q>", true, false, true)
  vim.api.nvim_feedkeys(keys, "m", false)
  vim.bo.scrollback = scrollback
end

vim.api.nvim_create_user_command(
  'Clear', clear_terminal, { desc = 'clear terminal window', nargs=0, }
)

M.inspect_lsp_client = function()
  vim.ui.input({ prompt = 'Enter LSP Client name: ' }, function(client_name)
    if client_name then
      local client = vim.lsp.get_clients { name = client_name }

      if #client == 0 then
        vim.notify('No active LSP clients found with this name: ' .. client_name, vim.log.levels.WARN)
        return
      end

      -- Create a temporary buffer to show the configuration
      local buf = vim.api.nvim_create_buf(false, true)
      local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = math.floor(vim.o.columns * 0.75),
        height = math.floor(vim.o.lines * 0.90),
        col = math.floor(vim.o.columns * 0.125),
        row = math.floor(vim.o.lines * 0.05),
        style = 'minimal',
        border = 'rounded',
        title = ' ' .. (client_name:gsub('^%l', string.upper)) .. ': LSP Configuration ',
        title_pos = 'center',
      })

      local lines = {}
      for i, this_client in ipairs(client) do
        if i > 1 then
          table.insert(lines, string.rep('-', 80))
        end
        table.insert(lines, 'Client: ' .. this_client.name)
        table.insert(lines, 'ID: ' .. this_client.id)
        table.insert(lines, '')
        table.insert(lines, 'Configuration:')

        local config_lines = vim.split(vim.inspect(this_client.config), '\n')
        vim.list_extend(lines, config_lines)
      end

      -- Set the lines in the buffer
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

      -- Set buffer options
      vim.bo[buf].modifiable = false
      vim.bo[buf].filetype = 'lua'
      vim.bo[buf].bh = 'delete'

      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
    end
  end)
end

return M

