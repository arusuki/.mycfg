local M = {}
local history_file = vim.fn.stdpath("state") .. "/grep-directories.json"

local function directories()
  local ok, history = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(history_file), "\n"))
  end)
  local result, seen = {}, {}
  local function add(path)
    if type(path) == "string" and not seen[path] and vim.fn.isdirectory(path) == 1 then
      seen[path] = true
      result[#result + 1] = path
    end
  end
  if ok and type(history) == "table" and vim.islist(history) then
    for _, path in ipairs(history) do
      add(path)
    end
  end
  return result
end

local function save_history(history)
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fn.fnamemodify(history_file, ":h"), "p")
    vim.fn.writefile({ vim.json.encode(history) }, history_file)
  end)
  if not ok then
    vim.notify("Could not save grep directory history: " .. tostring(err), vim.log.levels.WARN)
  end
  return ok
end

function M.grep(path)
  if not path or path == "" then
    return
  end
  path = vim.fs.normalize(vim.fn.fnamemodify(vim.fs.normalize(path), ":p"))
  if vim.fn.isdirectory(path) ~= 1 then
    vim.notify("Directory does not exist: " .. path, vim.log.levels.WARN)
    return
  end

  local history = { path }
  for _, dir in ipairs(directories()) do
    if dir ~= path and #history < 30 then
      history[#history + 1] = dir
    end
  end
  save_history(history)
  require("telescope.builtin").live_grep({
    cwd = path,
    prompt_title = "Grep: " .. path,
    additional_args = require("util").get_var("rg_args"),
  })
end

local function input_directory()
  -- Use command-line prompts so wilder-fzf can complete directories.
  local command = ":GrepDir " .. vim.fn.fnameescape(vim.fn.getcwd() .. "/")
  vim.api.nvim_feedkeys(command, "n", true)
end

function M.pick()
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entries = directories()
  local new_directory = "[New directory…]"
  entries[#entries + 1] = new_directory
  local opts = require("telescope.themes").get_dropdown({ previewer = false })
  require("telescope.pickers").new(opts, {
    prompt_title = "Grep directory (<C-o>: new, <C-x>: remove)",
    finder = require("telescope.finders").new_table({ results = entries }),
    sorter = require("telescope.config").values.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local function new()
        actions.close(prompt_bufnr)
        vim.schedule(input_directory)
      end
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        if not entry then
          return
        end
        if entry.value == new_directory then
          new()
        else
          actions.close(prompt_bufnr)
          vim.schedule(function() M.grep(entry.value) end)
        end
      end)
      map({ "i", "n" }, "<C-o>", new)
      map({ "i", "n" }, "<C-x>", function()
        local entry = action_state.get_selected_entry()
        if not entry or entry.value == new_directory then
          return
        end
        local history = vim.tbl_filter(function(dir)
          return dir ~= entry.value
        end, directories())
        if not save_history(history) then
          return
        end
        local results = vim.list_extend(history, { new_directory })
        action_state.get_current_picker(prompt_bufnr):refresh(
          require("telescope.finders").new_table({ results = results }),
          { reset_prompt = false }
        )
      end, { desc = "Remove directory from grep history" })
      return true
    end,
  }):find()
end

function M.setup()
  vim.api.nvim_create_user_command("GrepDir", function(opts)
    if opts.args == "" then
      M.pick()
    else
      M.grep(opts.fargs[1])
    end
  end, { nargs = "?", complete = "dir", desc = "Grep a directory, or select a recent one" })
  vim.keymap.set("n", "<leader>fd", M.pick, { desc = "Grep in a directory (with history)" })
end

return M
