vim.keymap.set("n", "<LeftMouse>", function()
  local left_mouse = vim.api.nvim_replace_termcodes(
    "<LeftMouse>",
    true,
    false,
    true
  )

  vim.api.nvim_feedkeys(left_mouse, "n", false)

  vim.schedule(function()
    if vim.bo.buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end)
end, {
  silent = true,
  desc = "Click terminal buffer and enter Terminal-mode",
})

local function feed_mouse(key)
  key = vim.api.nvim_replace_termcodes(key, true, false, true)
  vim.api.nvim_feedkeys(key, "n", false)
end

local function enter_terminal_mode()
  vim.schedule(function()
    if vim.bo.buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end)
end

vim.keymap.set({ "n", "t" }, "<2-LeftMouse>", function()
  local mouse = vim.fn.getmousepos()

  if mouse.winid ~= 0 and vim.api.nvim_win_is_valid(mouse.winid) then
    local buf = vim.api.nvim_win_get_buf(mouse.winid)

    if vim.bo[buf].buftype == "terminal" then
      feed_mouse("<LeftMouse>")
      enter_terminal_mode()
      return
    end
  end

  feed_mouse("<2-LeftMouse>")
end, {
  silent = true,
  desc = "Disable double-click selection in terminal",
})

local group = vim.api.nvim_create_augroup("terminal_file_open", {
  clear = true,
})

local function send_terminal_scroll(buf, button)
  if vim.bo[buf].buftype ~= "terminal" then
    return
  end

  local job = vim.b[buf].terminal_job_id
  if not job or vim.fn.jobwait({ job }, 0)[1] ~= -1 then
    return
  end

  -- Send SGR mouse input at the terminal center without leaving Normal mode.
  local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local col = math.max(1, math.floor((info.width - info.textoff) / 2))
  local row = math.max(1, math.floor(info.height / 2))
  local event = string.format("\027[<%d;%d;%dM", button, col, row)
  vim.api.nvim_chan_send(job, event:rep(vim.v.count1))
end

vim.api.nvim_create_autocmd("TermRequest", {
  group = group,
  callback = function(ev)
    local dir, n =
      ev.data.sequence:gsub("\027]7;file://[^/]*", "")

    if n == 0 then
      return
    end

    if vim.fn.isdirectory(dir) == 1 then
      vim.b[ev.buf].osc7_dir = dir
    end
  end,
})

local function configure_terminal(buf)
  -- Reloading this file must also update terminals that are already open.
  local old_scroll_maps = {
    ["<C-k>"] = "Send scroll wheel up to terminal",
    ["<C-j>"] = "Send scroll wheel down to terminal",
  }
  for key, desc in pairs(old_scroll_maps) do
    local mapping = vim.api.nvim_buf_call(buf, function()
      return vim.fn.maparg(key, "n", false, true)
    end)
    if mapping.buffer == 1 and mapping.desc == desc then
      vim.keymap.del("n", key, { buffer = buf })
    end
  end

  vim.keymap.set("n", "K", function()
    send_terminal_scroll(buf, 64)
  end, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = "Send scroll wheel up to terminal",
  })
  vim.keymap.set("n", "J", function()
    send_terminal_scroll(buf, 65)
  end, {
    buffer = buf,
    silent = true,
    nowait = true,
    desc = "Send scroll wheel down to terminal",
  })

  vim.keymap.set("n", "<CR>", function()
    local file = vim.fn.expand("<cfile>")

    if file == "" then
      return
    end

    local cwd = vim.b[buf].osc7_dir or vim.fn.getcwd()

    local path
    if file:sub(1, 1) == "/" then
      path = file
    else
      path = cwd .. "/" .. file
    end

    if vim.fn.filereadable(path) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
  end, {
    buffer = buf,
    silent = true,
    desc = "Open terminal file under cursor",
  })
end

vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  callback = function(ev)
    configure_terminal(ev.buf)
  end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "terminal" then
    configure_terminal(buf)
  end
end
