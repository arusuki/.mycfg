local function is_visual_mode()
  local mode = vim.fn.mode()
  return mode == "v" or mode == "V" or mode == "\22"
end

local function normalize_range(p1, p2)
  local sr, sc = p1[2] - 1, p1[3] - 1
  local er, ec = p2[2] - 1, p2[3] - 1

  if sr > er or (sr == er and sc > ec) then
    sr, er = er, sr
    sc, ec = ec, sc
  end

  -- Vim 的 col 是 1-based inclusive；
  -- Tree-sitter range 是 0-based end-exclusive。
  ec = ec + 1

  return sr, sc, er, ec
end

local function selected_range()
  if is_visual_mode() then
    return normalize_range(vim.fn.getpos("v"), vim.fn.getpos("."))
  else
    return normalize_range(vim.fn.getpos("'<"), vim.fn.getpos("'>"))
  end
end

local function node_from_selection()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    return vim.treesitter.get_node()
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local sr, sc, er, ec = selected_range()
  return tree:root():named_descendant_for_range(sr, sc, er, ec)
end

local function same_node(a, b)
  if not a or not b then
    return false
  end

  local ar, ac, aer, aec = a:range()
  local br, bc, ber, bec = b:range()

  return a:type() == b:type()
    and ar == br
    and ac == bc
    and aer == ber
    and aec == bec
end

local function is_named(node)
  local ok, named = pcall(function()
    return node:named()
  end)
  return ok and named
end

local function parent_info(parent, node)
  local named_count = 0
  local field_name = nil

  for child, field in parent:iter_children() do
    if is_named(child) then
      named_count = named_count + 1
    end

    if same_node(child, node) then
      field_name = field
    end
  end

  return field_name, named_count
end

local function get_sibling(node, direction)
  if direction == "next" then
    return node:next_named_sibling()
  else
    return node:prev_named_sibling()
  end
end

local function find_horizontal_target(node, direction)
  local cur = node

  while cur do
    local sibling = get_sibling(cur, direction)
    if sibling then
      return sibling
    end

    local parent = cur:parent()
    if not parent then
      return nil
    end

    local field_name, named_count = parent_info(parent, cur)

    -- 如果当前节点已经是一个“列表元素”，并且这个方向没有兄弟节点，
    -- 就不要继续往更外层跳了。
    --
    -- 例如 find_files 是 pickers 表里的第一个 field：
    -- M-h 应该无事发生，而不是跳到 pickers 的上一个兄弟。
    if field_name == nil and named_count > 1 then
      return nil
    end

    cur = parent
  end

  return nil
end

local function select_node(node)
  local ok, utils = pcall(require, "wildfire.utils")

  if ok and utils.update_selection then
    utils.update_selection(vim.api.nvim_get_current_buf(), node)
    return
  end

  -- fallback，不依赖 wildfire 内部 API
  local sr, sc, er, ec = node:range()
  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { er + 1, math.max(ec - 1, 0) })
end

local function move_sibling(direction)
  local node = node_from_selection()
  if not node then
    return
  end

  local target = find_horizontal_target(node, direction)
  if target then
    select_node(target)
  end
end

local function split_keep_empty(s)
  local lines = {}
  local start = 1

  while true do
    local idx = string.find(s, "\n", start, true)
    if not idx then
      table.insert(lines, string.sub(s, start))
      break
    end

    table.insert(lines, string.sub(s, start, idx - 1))
    start = idx + 1
  end

  return lines
end

local function buf_to_string(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function pos_to_offset(buf, row, col)
  local ok, offset = pcall(vim.api.nvim_buf_get_offset, buf, row)
  if ok and offset >= 0 then
    return offset + col
  end

  -- fallback
  local lines = vim.api.nvim_buf_get_lines(buf, 0, row, false)
  local acc = 0
  for _, line in ipairs(lines) do
    acc = acc + #line + 1
  end
  return acc + col
end

local function offset_to_pos(buf, offset)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local acc = 0

  for i, line in ipairs(lines) do
    local len = #line

    if offset <= acc + len then
      return i - 1, offset - acc
    end

    acc = acc + len + 1
  end

  local last = lines[#lines] or ""
  return math.max(#lines - 1, 0), #last
end

local function visual_end_pos(buf, er, ec)
  if ec > 0 then
    return er, ec - 1
  end

  if er > 0 then
    local prev = vim.api.nvim_buf_get_lines(buf, er - 1, er, false)[1] or ""
    return er - 1, math.max(#prev - 1, 0)
  end

  return er, ec
end

local function select_range(sr, sc, er, ec)
  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
  vim.cmd("normal! v")

  local vr, vc = visual_end_pos(buf, er, ec)
  vim.api.nvim_win_set_cursor(0, { vr + 1, vc })
end

local function sibling_group(node)
  local parent = node:parent()
  if not parent then
    return nil, nil
  end

  local current_field = nil
  local found = false

  for child, field in parent:iter_children() do
    if same_node(child, node) then
      current_field = field
      found = true
      break
    end
  end

  if not found then
    return nil, nil
  end

  local siblings = {}
  local current_index = nil

  for child, field in parent:iter_children() do
    -- 只在同一个 field_name 下移动。
    -- 对函数参数、数组元素、table entries 这类列表，field 通常是 nil。
    -- 这可以避免把 function name 和 arguments 这种结构性节点互换。
    if is_named(child) and field == current_field then
      table.insert(siblings, child)

      if same_node(child, node) then
        current_index = #siblings
      end
    end
  end

  if #siblings <= 1 or not current_index then
    return nil, nil
  end

  return siblings, current_index
end

local function find_movable_node(node)
  local cur = node

  while cur do
    local siblings, index = sibling_group(cur)
    if siblings then
      return cur, siblings, index
    end

    local parent = cur:parent()
    if not parent then
      return nil, nil, nil
    end

    local field_name, named_count = parent_info(parent, cur)

    -- 允许穿过“包装节点”，比如 string_content -> string；
    -- 但不要从 function name、binary left/right、key/value 这类结构字段继续往外跳。
    if field_name ~= nil or named_count > 1 then
      return nil, nil, nil
    end

    cur = parent
  end

  return nil, nil, nil
end

local function node_range_info(buf, node)
  local sr, sc, er, ec = node:range()

  return {
    sr = sr,
    sc = sc,
    er = er,
    ec = ec,
    start_offset = pos_to_offset(buf, sr, sc),
    end_offset = pos_to_offset(buf, er, ec),
  }
end

local function move_selected_sibling_text(direction)
  local buf = vim.api.nvim_get_current_buf()
  local node = node_from_selection()

  if not node then
    return
  end

  local movable, siblings, index = find_movable_node(node)
  if not movable or not siblings or not index then
    return
  end

  local n = #siblings
  local content = buf_to_string(buf)

  local ranges = {}
  local old_texts = {}

  for i, sibling in ipairs(siblings) do
    local r = node_range_info(buf, sibling)
    ranges[i] = r
    old_texts[i] = string.sub(content, r.start_offset + 1, r.end_offset)
  end

  local new_texts = {}
  for i, text in ipairs(old_texts) do
    new_texts[i] = text
  end

  local new_index

  if direction == "next" then
    if index < n then
      new_texts[index], new_texts[index + 1] = old_texts[index + 1], old_texts[index]
      new_index = index + 1
    else
      -- 最后一个向后跳：移动到第一个，其它整体右移
      new_texts[1] = old_texts[n]
      for i = 2, n do
        new_texts[i] = old_texts[i - 1]
      end
      new_index = 1
    end
  else
    if index > 1 then
      new_texts[index], new_texts[index - 1] = old_texts[index - 1], old_texts[index]
      new_index = index - 1
    else
      -- 第一个向前跳：移动到最后一个，其它整体左移
      for i = 1, n - 1 do
        new_texts[i] = old_texts[i + 1]
      end
      new_texts[n] = old_texts[1]
      new_index = n
    end
  end

  -- 先退出 visual，避免编辑 buffer 后 visual marks 干扰。
  vim.cmd("normal! \027")

  -- 从后往前改，避免前面的 edit 影响后面 node 的原始 range。
  for i = n, 1, -1 do
    if new_texts[i] ~= old_texts[i] then
      local r = ranges[i]
      vim.api.nvim_buf_set_text(
        buf,
        r.sr,
        r.sc,
        r.er,
        r.ec,
        split_keep_empty(new_texts[i])
      )
    end
  end

  -- 计算移动后的文本在最终 buffer 里的位置。
  local delta_before = 0
  for i = 1, new_index - 1 do
    delta_before = delta_before + #new_texts[i] - #old_texts[i]
  end

  local moved_text = old_texts[index]
  local new_start_offset = ranges[new_index].start_offset + delta_before
  local new_end_offset = new_start_offset + #moved_text

  local sr, sc = offset_to_pos(buf, new_start_offset)
  local er, ec = offset_to_pos(buf, new_end_offset)

  select_range(sr, sc, er, ec)
end

vim.keymap.set({ "x", "n" }, "<M-l>", function()
  move_sibling("next")
end, { desc = "Select next sibling AST node" })

vim.keymap.set({ "x", "n" }, "<M-h>", function()
  move_sibling("prev")
end, { desc = "Select previous sibling AST node" })

vim.keymap.set("x", "<M-.>", function()
  move_selected_sibling_text("next")
end, { desc = "Move selected AST node to next sibling" })

vim.keymap.set("x", "<M-,>", function()
  move_selected_sibling_text("prev")
end, { desc = "Move selected AST node to previous sibling" })
