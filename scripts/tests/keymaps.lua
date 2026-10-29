-- Static check for literal, global vim.keymap.set mappings. Run with Lua + luacheck.
-- Dynamic keys, buffer-local mappings, and plugin-owned mappings need runtime tests.
local parser = require("luacheck.parser")
local decoder = require("luacheck.decoder")
local lfs = require("lfs")
local seen, errors, checked = {}, 0, 0

local function path(node)
  if node.tag == "Id" then return node[1] end
  if node.tag == "Index" and node[2].tag == "String" then
    return (path(node[1]) or "?") .. "." .. node[2][1]
  end
end

local function check(node, file)
  if node.tag ~= "Call" or path(node[1]) ~= "vim.keymap.set" or not node[3] or node[3].tag ~= "String" then
    return
  end
  local opts = node[5]
  if opts and opts.tag == "Table" then
    for _, entry in ipairs(opts) do
      if entry.tag == "Pair" and entry[1][1] == "buffer" and entry[2].tag ~= "False" then
        return
      end
    end
  end
  local modes = node[2].tag == "Table" and node[2] or { node[2] }
  local lhs = node[3][1]:gsub("<[^>]+>", string.lower)
  for _, mode in ipairs(modes) do
    if mode.tag == "String" then
      local expanded = ({ v = { "x", "s" }, [""] = { "n", "x", "s", "o" }, ["!"] = { "i", "c" } })[mode[1]] or { mode[1] }
      for _, name in ipairs(expanded) do
        local key = name .. ":" .. lhs
        local location = file .. ":" .. node.line
        if seen[key] then
          io.stderr:write(location .. ": duplicate " .. key .. " (first defined at " .. seen[key] .. ")\n")
          errors = errors + 1
        else
          seen[key] = location
          checked = checked + 1
        end
      end
    end
  end
end

local function walk(node, file)
  if type(node) ~= "table" then return end
  check(node, file)
  for _, child in ipairs(node) do walk(child, file) end
end

local function scan(file)
  if lfs.attributes(file, "mode") == "directory" then
    local names = {}
    for name in lfs.dir(file) do
      if name ~= "." and name ~= ".." then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do scan(file .. "/" .. name) end
  elseif file:match("%.lua$") then
    local handle = assert(io.open(file))
    local source = handle:read("*a")
    handle:close()
    walk(parser.parse(decoder.decode(source)), file)
  end
end

assert(arg[1], "Usage: lua scripts/tests/keymaps.lua PATH...")
for _, file in ipairs(arg) do scan(file) end
assert(errors == 0, "duplicate global keymaps found")
print("PASS: " .. checked .. " literal global keymaps checked")
