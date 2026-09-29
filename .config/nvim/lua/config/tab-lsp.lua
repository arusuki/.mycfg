-- Tab-local :lsp enable/disable, with project-based client reuse.
-- scope.nvim owns buffer membership; a shared buffer follows the active tab.
local M = {}
local enabled, clients = {}, {}
local configured = {}
local generation = 0
local queued = false

local function matches(config, buf)
  return vim.api.nvim_buf_is_loaded(buf)
    and vim.bo[buf].buftype == ""
    and (not config.filetypes or vim.tbl_contains(config.filetypes, vim.bo[buf].filetype))
end

local function desired_buffers()
  local current = vim.api.nvim_get_current_tabpage()
  local membership = {}
  local scope = require("scope.core")
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local buffers = tab == current and require("scope.utils").get_valid_buffers() or scope.cache[tab] or {}
    membership[tab] = {}
    for _, buf in ipairs(buffers) do
      membership[tab][buf] = true
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      membership[tab][vim.api.nvim_win_get_buf(win)] = true
    end
  end

  local desired = {}
  for tab, names in pairs(enabled) do
    if not membership[tab] then
      enabled[tab] = nil
    else
      for buf in pairs(membership[tab]) do
        -- An inactive tab must not reattach a buffer disabled in the active tab.
        if tab == current or not membership[current][buf] then
          desired[buf] = desired[buf] or {}
          for name in pairs(names) do
            desired[buf][name] = true
          end
        end
      end
    end
  end
  return desired
end

local function diagnostics(client, buf, enable)
  for _, pull in ipairs({ false, true }) do
    vim.diagnostic.enable(enable, {
      bufnr = buf,
      ns_id = vim.lsp.diagnostic.get_namespace(client.id, pull),
    })
  end
end

function M.refresh()
  generation = generation + 1
  local revision = generation
  local desired = desired_buffers()

  -- Detach documents, never stop a process another tab may still use.
  for id in pairs(clients) do
    local client = vim.lsp.get_client_by_id(id)
    if not client or client:is_stopped() then
      clients[id] = nil
    else
      for buf in pairs(vim.deepcopy(client.attached_buffers)) do
        local config = vim.lsp.config[client.name]
        if not (desired[buf] and desired[buf][client.name] and config and matches(config, buf)) then
          diagnostics(client, buf, false)
          vim.lsp.buf_detach_client(buf, id)
        end
      end
    end
  end

  for buf, names in pairs(desired) do
    for name in pairs(names) do
      local config = vim.lsp.config[name]
      local attached = false
      for id in pairs(clients) do
        local client = vim.lsp.get_client_by_id(id)
        if client and client.name == name and vim.lsp.buf_is_attached(buf, id) then
          attached = true
          break
        end
      end
      if config and matches(config, buf) and not attached then
        config = vim.deepcopy(config)
        local function start(root)
          vim.schedule(function()
            -- A root resolver may finish after a tab switch, disable, or wipeout.
            local wanted = desired_buffers()[buf]
            if generation ~= revision or not (wanted and wanted[name]) or not matches(config, buf) then
              return
            end
            config.root_dir = root
            if not root and not config.workspace_folders and config.workspace_required then
              return
            end
            if type(config.cmd) == "table" and vim.fn.executable(config.cmd[1]) == 0 then
              return
            end
            -- Re-enable diagnostics before didOpen can deliver new results.
            for id in pairs(clients) do
              local client = vim.lsp.get_client_by_id(id)
              if client and client.name == name then
                diagnostics(client, buf, true)
              end
            end
            local id = vim.lsp.start(config, { bufnr = buf, reuse_client = config.reuse_client })
            if id then
              clients[id] = true
            end
          end)
        end
        if type(config.root_dir) == "function" then
          config.root_dir(buf, start)
        else
          start(config.root_dir or (config.root_markers and vim.fs.root(buf, config.root_markers)))
        end
      end
    end
  end
end

local function schedule_refresh()
  if queued then
    return
  end
  queued = true
  vim.schedule(function()
    queued = false
    M.refresh()
  end)
end

function M.enable(names, enable)
  names = type(names) == "string" and { names } or names
  for _, name in ipairs(names) do
    if name == "*" or not vim.lsp.config[name] then
      error("No LSP config named " .. name)
    end
  end
  local tab = vim.api.nvim_get_current_tabpage()
  enabled[tab] = enabled[tab] or {}
  for _, name in ipairs(names) do
    enabled[tab][name] = enable ~= false and true or nil
  end
  M.refresh()
end

function M.setup(names)
  configured = names
  local group = vim.api.nvim_create_augroup("TabScopedLsp", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "FileType", "TabEnter", "TabClosed", "BufDelete", "SessionLoadPost" }, {
    group = group,
    callback = schedule_refresh,
  })

  -- Nvim 0.12 implements the built-in lowercase :lsp command here. Adapt only
  -- enable/disable and their completion; leave the global Lua API unchanged.
  local command = require("vim._core.ex_cmd")
  local original, complete = command.ex_lsp, command.lsp_complete
  command.ex_lsp = function(args)
    local words = vim.api.nvim_parse_cmd("lsp " .. args, {}).args
    local action = table.remove(words, 1)
    if action ~= "enable" and action ~= "disable" then
      return original(args)
    end
    if #words == 0 then
      if action == "disable" then
        words = vim.tbl_keys(enabled[vim.api.nvim_get_current_tabpage()] or {})
      else
        for _, name in ipairs(configured) do
          local config = vim.lsp.config[name]
          if config and matches(config, vim.api.nvim_get_current_buf()) then
            words[#words + 1] = name
          end
        end
      end
    end
    M.enable(words, action == "enable")
  end
  command.lsp_complete = function(line)
    local action = line:match("^%s*lsp%s+(%S+)%s")
    if action == "disable" then
      return vim.tbl_keys(enabled[vim.api.nvim_get_current_tabpage()] or {})
    elseif action == "enable" then
      local active = enabled[vim.api.nvim_get_current_tabpage()] or {}
      return vim.tbl_filter(function(name)
        return not active[name]
      end, complete(line))
    end
    return complete(line)
  end
end

return M
