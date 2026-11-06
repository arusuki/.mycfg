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
  require("fzf-lua").live_grep(require("config.fzf-grep").opts({
    cwd = path,
    winopts = { title = "Grep: " .. path },
  }))
end

local function input_directory()
  -- Use command-line prompts to retain native directory completion.
  local command = ":GrepDir " .. vim.fn.fnameescape(vim.fn.getcwd() .. "/")
  vim.api.nvim_feedkeys(command, "n", true)
end

function M.pick()
  local new_directory = "[New directory…]"
  local function new()
    vim.schedule(input_directory)
  end
  require("fzf-lua").fzf_exec(function(cb)
    for _, dir in ipairs(directories()) do
      cb(dir)
    end
    cb(new_directory)
    cb(nil)
  end, {
    prompt = "Grep directory> ",
    winopts = { title = "Grep directory", width = 0.7, height = 0.4 },
    previewer = false,
    fzf_opts = { ["--no-multi"] = true },
    actions = {
      ["enter"] = function(selected)
        if not selected[1] then
          return
        end
        if selected[1] == new_directory then
          new()
        else
          vim.schedule(function() M.grep(selected[1]) end)
        end
      end,
      ["ctrl-o"] = { fn = new, desc = "New directory" },
      ["ctrl-x"] = {
        fn = function(selected)
          if not selected[1] or selected[1] == new_directory then
            return
          end
          save_history(vim.tbl_filter(function(dir)
            return dir ~= selected[1]
          end, directories()))
        end,
        reload = true,
        desc = "Remove directory from history",
      },
    },
  })
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
