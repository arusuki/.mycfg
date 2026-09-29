local M = {}
local snapshots = {}

local function first_window(layout)
  while layout[1] ~= "leaf" do
    layout = layout[2][1]
  end
  return layout[2]
end

-- Keep scratch buffers and running terminals alive while their windows close.
local function with_hidden_buffers(callback)
  local options = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if options[buf] == nil then
      options[buf] = vim.bo[buf].bufhidden
      vim.bo[buf].bufhidden = "hide"
    end
  end
  local ok, err = pcall(callback)
  for buf, value in pairs(options) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.bo[buf].bufhidden = value
    end
  end
  if not ok then
    vim.notify("Could not change window layout: " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

function M.maximize()
  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current).relative ~= "" then
    return
  end

  local snapshot = {
    layout = vim.fn.winlayout(),
    current = current,
    sizes = vim.fn.winrestcmd(),
    windows = {},
  }
  local can_close = false
  local function capture(layout)
    if layout[1] ~= "leaf" then
      for _, child in ipairs(layout[2]) do
        capture(child)
      end
      return
    end
    local win = layout[2]
    local buf = vim.api.nvim_win_get_buf(win)
    snapshot.windows[win] = {
      buf = buf,
      terminal = vim.bo[buf].buftype == "terminal",
      winfixheight = vim.wo[win].winfixheight,
      winfixwidth = vim.wo[win].winfixwidth,
    }
    if win ~= current and not vim.api.nvim_buf_get_name(buf):find("Trouble") then
      can_close = true
    end
  end
  capture(snapshot.layout)

  -- Repeating wo on an already maximized layout must not erase the snapshot.
  if not can_close then
    return
  end
  snapshots[vim.api.nvim_get_current_tabpage()] = snapshot
  with_hidden_buffers(function()
    require("util").close_all_other_windows({ "Trouble" })
  end)
end

function M.restore()
  local tab = vim.api.nvim_get_current_tabpage()
  local snapshot = snapshots[tab]
  if not snapshot then
    vim.notify("No window layout to restore in this tab", vim.log.levels.INFO)
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  -- The window kept by wo may now show a different buffer; keep its live state.
  local kept_win = snapshot.current
  if not vim.api.nvim_win_is_valid(kept_win) or vim.api.nvim_win_get_tabpage(kept_win) ~= tab then
    kept_win = nil
  end
  local restored = {}
  local equalalways = vim.o.equalalways
  vim.o.equalalways = true
  local ok = with_hidden_buffers(function()
    local replacements = {}
    for old_win, window in pairs(snapshot.windows) do
      if old_win ~= kept_win and (window.deleted or not vim.api.nvim_buf_is_valid(window.buf)) then
        local buf = replacements[window.buf]
        if not buf then
          buf = current_buf
          if window.terminal then
            buf = vim.api.nvim_create_buf(true, false)
            local started, err = pcall(vim.api.nvim_buf_call, buf, function()
              assert(vim.fn.jobstart(vim.o.shell, { term = true }) > 0,
                "Could not start replacement terminal")
            end)
            if not started then
              vim.api.nvim_buf_delete(buf, { force = true })
              error(err)
            end
          end
          replacements[window.buf] = buf
        end
        window.buf = buf
        window.deleted = nil
      end
    end

    for win in pairs(snapshot.windows) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_tabpage(win) == tab then
        restored[win] = win
        vim.wo[win].winfixheight = false
        vim.wo[win].winfixwidth = false
      end
    end
    local function place(old_win, target, split)
      local win = old_win
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_tabpage(win) == tab then
        if target then
          vim.api.nvim_win_set_config(win, { win = target, split = split })
        end
      else
        win = vim.api.nvim_open_win(snapshot.windows[old_win].buf, false, {
          win = target or -1,
          split = split or "left",
        })
      end
      restored[old_win] = win
      vim.wo[win].winfixheight = false
      vim.wo[win].winfixwidth = false
      return win
    end

    local root = place(first_window(snapshot.layout))
    -- Retain surviving windows (including Trouble) so their plugin state lives on.
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if win ~= root and not snapshot.windows[win]
        and vim.api.nvim_win_get_config(win).relative == "" then
        vim.api.nvim_win_close(win, false)
      end
    end

    local function rebuild(layout, anchor)
      if layout[1] == "leaf" then
        return
      end
      local children = layout[2]
      local anchors = { anchor }
      local split = layout[1] == "row" and "right" or "below"
      -- Create sibling frames before subdividing them into nested splits.
      for i = 2, #children do
        anchors[i] = place(first_window(children[i]), anchors[i - 1], split)
      end
      for i, child in ipairs(children) do
        rebuild(child, anchors[i])
      end
    end
    rebuild(snapshot.layout, root)

    for old_win, win in pairs(restored) do
      local buf = snapshot.windows[old_win].buf
      if win ~= kept_win and vim.api.nvim_win_get_buf(win) ~= buf then
        vim.api.nvim_win_set_buf(win, buf)
      end
    end
    vim.api.nvim_set_current_win(restored[snapshot.current])
    vim.o.equalalways = equalalways
    vim.cmd(snapshot.sizes)
  end)
  if vim.o.equalalways ~= equalalways then
    vim.o.equalalways = equalalways
  end
  for old_win, win in pairs(restored) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winfixheight = snapshot.windows[old_win].winfixheight
      vim.wo[win].winfixwidth = snapshot.windows[old_win].winfixwidth
    end
  end
  if ok then
    snapshots[tab] = nil
  end
end

local group = vim.api.nvim_create_augroup("WindowLayoutSnapshots", { clear = true })

-- :bdelete can leave a valid buffer handle, so validity alone is not enough.
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(ev)
    for _, snapshot in pairs(snapshots) do
      for _, window in pairs(snapshot.windows) do
        if window.buf == ev.buf then
          window.deleted = true
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("TabClosed", {
  group = group,
  callback = function()
    for tab in pairs(snapshots) do
      if not vim.api.nvim_tabpage_is_valid(tab) then
        snapshots[tab] = nil
      end
    end
  end,
})

return M
