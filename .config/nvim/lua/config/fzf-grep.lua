local M = {}

function M.opts(overrides)
  -- EditVar stores one argument per line, just like an argv list. Quote each
  -- argument before handing it to fzf-lua's shell command builder.
  local args = vim.tbl_map(vim.fn.shellescape, require("util").get_var("rg_args") or {})
  local rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096"
  return vim.tbl_extend("force", {
    rg_opts = rg_opts .. " " .. table.concat(args, " ") .. " -e",
    rg_glob = false,
  }, overrides or {})
end

return M
