local M = {}

local function field(node, name)
  return node:field(name)[1]
end

-- Find a declared name without mistaking a function prototype for a value.
local function declared_name(node)
  local is_function = false
  while node do
    local kind = node:type()
    if kind == "identifier" or kind == "type_identifier" then
      return node, is_function
    end
    is_function = is_function or kind == "function_declarator"
    node = field(node, "declarator")
      or (kind == "reference_declarator" and node:named_child(0))
      or nil
  end
end

-- Inspect only declarations in this scope, never declarations inside a sibling
-- block/function. A type binding must stop lookup just as a value binding does.
local function binding_in(node, name, source)
  local kind = node:type()
  local function matches(identifier)
    return identifier and vim.treesitter.get_node_text(identifier, source) == name
  end
  if kind == "alias_declaration" or kind == "class_specifier"
    or kind == "struct_specifier" or kind == "enum_specifier" then
    return matches(field(node, "name")) and "type" or nil
  end
  if kind == "type_parameter_declaration" then
    return matches(node:named_child(0)) and "type" or nil
  end
  if kind == "declaration" or kind == "parameter_declaration"
    or kind == "optional_parameter_declaration" or kind == "type_definition" then
    for _, declarator in ipairs(node:field("declarator")) do
      local identifier, is_function = declared_name(declarator)
      if matches(identifier) then
        return kind == "type_definition" and "type" or (is_function and "function" or "value")
      end
    end
    local type_node = field(node, "type")
    if type_node and matches(field(type_node, "name")) then
      return "type"
    end
  end
end

local function parameter_binding(parameters, name, source)
  if not parameters then return end
  for child in parameters:iter_children() do
    local binding = binding_in(child, name, source)
    if binding then return binding end
  end
end

local function visible_binding(use, name, source)
  local node = use
  while node do
    local sibling = node:prev_named_sibling()
    while sibling do
      local binding = binding_in(sibling, name, source)
      if binding then return binding end
      sibling = sibling:prev_named_sibling()
    end
    local parent = node:parent()
    if parent and parent:type() == "function_definition" then
      local declarator = field(parent, "declarator")
      while declarator and declarator:type() ~= "function_declarator" do
        declarator = field(declarator, "declarator")
      end
      local binding = parameter_binding(declarator and field(declarator, "parameters"), name, source)
      if binding then return binding end
    elseif parent and parent:type() == "template_declaration" then
      local binding = parameter_binding(field(parent, "parameters"), name, source)
      if binding then return binding end
    elseif parent and (parent:type() == "lambda_expression" or parent:type() == "field_declaration_list") then
      -- Captures and class/member lookup need more semantic context. Abstain.
      return nil
    end
    node = parent
  end
end

function M.kind(identifier, kind, source)
  if kind ~= "function" then return kind end
  local declarator = identifier:parent()
  local declaration = declarator and declarator:parent()
  if not declarator or declarator:type() ~= "function_declarator"
    or not declaration or declaration:type() ~= "declaration" then
    return kind
  end
  local parameters = field(declarator, "parameters")
  if not parameters or parameters:named_child_count() == 0 then return kind end

  -- C++/CUDA may parse `View view(pointer);` as a function with an unnamed
  -- parameter of type `pointer`. Correct only simple identifier arguments
  -- whose earlier, visible declarations establish that they are values.
  for parameter in parameters:iter_children() do
    if parameter:named() then
      local type_node = field(parameter, "type")
      if parameter:type() ~= "parameter_declaration" or parameter:named_child_count() ~= 1
        or not type_node or type_node:type() ~= "type_identifier" then
        return kind
      end
      local name = vim.treesitter.get_node_text(type_node, source)
      if visible_binding(declaration, name, source) ~= "value" then return kind end
    end
  end
  return "var"
end

function M.open()
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = { bufnr = bufnr }
  if vim.bo[bufnr].filetype == "cpp" or vim.bo[bufnr].filetype == "cuda" then
    -- fzf-lua resumes its producer from a libuv write callback. Buffer reads
    -- there raise E5560 and terminate the remaining symbol stream. Snapshot
    -- before opening the picker; get_node_text(node, string) needs no Vim API.
    local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
    opts.node_filter = function(entry, kind)
      -- fzf-lua formats entry.kind after invoking this callback. Preserve all
      -- entries and source positions; only correct the displayed symbol kind.
      entry.kind = M.kind(entry.node, kind, source)
      return true
    end
  end
  require("fzf-lua").treesitter(opts)
end

return M
