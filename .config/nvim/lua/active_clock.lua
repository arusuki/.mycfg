local M = {}

local uv = vim.uv or vim.loop
local api, fn = vim.api, vim.fn
local floor, min, max = math.floor, math.min, math.max

local defaults = {
  idle_seconds = 60,
  pressure_window_seconds = 10 * 60,
  show_pressure_window_breakdown = false,
  pressure_bar = {
    width = 10,
    filled = "█",
    empty = "░",
    background_highlight = "lualine_c_normal",
    lualine_section = "c",
    colors = {
      low = { fg = "#5fd700", ctermfg = 76 },
      medium = { fg = "#ffaf00", ctermfg = 214 },
      high = { fg = "#ff5f5f", ctermfg = 203 },
      empty = { fg = "#6c7086", ctermfg = 242 },
    },
  },
  pressure_thresholds = { low = 30, high = 70 },
  auto_load = true,
  save_file = fn.stdpath("state") .. "/active-clock/state.json",
  notify = true,
  frames = { "ᕕ( ᐛ )ᕗ", "ᕗ( ᐛ )ᕕ" },
  idle_frame = "(-_-) zZ",
}

local config = vim.deepcopy(defaults)
local records = {}

local now = uv.now()
local last_activity, last_tick = now, now
local timer
local running = true
local terminal_mode = false
local refresh_pending = false

local recent_runs = {}
local recent_head, recent_tail = 1, 0
local recent_seconds, recent_active = 0, 0

local highlight_signature
local highlight_context
local highlight_resolved = false
local restore_highlight = "StatusLine"

local input_namespace = api.nvim_create_namespace("ActiveClockInput")
local supports_typed_key = fn.has("nvim-0.10") == 1

local function clamp(value, lower, upper)
  return min(upper, max(lower, value))
end

local function to_uint(value, fallback)
  value = tonumber(value)
  return value and max(0, floor(value)) or fallback or 0
end

local function notify(message, level)
  if config.notify then
    vim.notify(message, level or vim.log.levels.INFO, { title = "ActiveClock" })
  end
end

local function format_time(seconds)
  seconds = to_uint(seconds)
  return string.format(
    "%02d:%02d:%02d",
    floor(seconds / 3600),
    floor(seconds % 3600 / 60),
    seconds % 60
  )
end

local function format_duration_short(seconds)
  seconds = to_uint(seconds)
  local hours = floor(seconds / 3600)
  local minutes = floor(seconds % 3600 / 60)
  local secs = seconds % 60

  if hours > 0 then
    return minutes > 0 and string.format("%dh%02dm", hours, minutes) or string.format("%dh", hours)
  end
  if minutes > 0 then
    return secs > 0 and string.format("%dm%02ds", minutes, secs) or string.format("%dm", minutes)
  end
  return string.format("%ds", secs)
end

local function date_key(timestamp)
  return os.date("%Y-%m-%d", timestamp or os.time())
end

local function get_record(day, create)
  day = day or date_key()
  local record = records[day]

  if not record and create ~= false then
    record = { active_seconds = 0, inactive_seconds = 0, updated_at = os.time() }
    records[day] = record
  end

  return record
end

local function get_today_record()
  return get_record(date_key(), true)
end

local function next_midnight(timestamp)
  local parts = os.date("*t", timestamp)
  parts.hour, parts.min, parts.sec = 0, 0, 0
  parts.day = parts.day + 1
  parts.isdst = nil

  local value = os.time(parts)
  return value and value > timestamp and value or timestamp + 86400
end

local function add_record_seconds(start_timestamp, seconds, field)
  local remaining = to_uint(seconds)
  local cursor = floor(start_timestamp)
  local updated_at = os.time()

  while remaining > 0 do
    local boundary = next_midnight(cursor)
    local chunk = min(remaining, boundary - cursor)
    if chunk <= 0 then
      chunk = remaining
    end

    local record = get_record(date_key(cursor), true)
    record[field] = to_uint(record[field]) + chunk
    record.updated_at = updated_at
    cursor = cursor + chunk
    remaining = remaining - chunk
  end
end

local function clear_recent()
  recent_runs = {}
  recent_head, recent_tail = 1, 0
  recent_seconds, recent_active = 0, 0
end

local function compact_recent()
  if recent_head < 64 or recent_head * 2 <= recent_tail then
    return
  end

  local compacted = {}
  for index = recent_head, recent_tail do
    compacted[#compacted + 1] = recent_runs[index]
  end

  recent_runs = compacted
  recent_head, recent_tail = 1, #compacted
end

local function push_recent(active, seconds)
  local count = to_uint(seconds)
  local capacity = config.pressure_window_seconds

  if count == 0 then
    return
  end

  if count >= capacity then
    recent_runs = { { active = active, seconds = capacity } }
    recent_head, recent_tail = 1, 1
    recent_seconds = capacity
    recent_active = active and capacity or 0
    return
  end

  local tail = recent_runs[recent_tail]
  if tail and tail.active == active then
    tail.seconds = tail.seconds + count
  else
    recent_tail = recent_tail + 1
    recent_runs[recent_tail] = { active = active, seconds = count }
  end

  recent_seconds = recent_seconds + count
  if active then
    recent_active = recent_active + count
  end

  local overflow = recent_seconds - capacity
  while overflow > 0 do
    local head = recent_runs[recent_head]
    local removed = min(overflow, head.seconds)

    head.seconds = head.seconds - removed
    recent_seconds = recent_seconds - removed
    if head.active then
      recent_active = recent_active - removed
    end
    overflow = overflow - removed

    if head.seconds == 0 then
      recent_runs[recent_head] = nil
      recent_head = recent_head + 1
    end
  end

  compact_recent()
end

local function seed_recent(record)
  clear_recent()

  local capacity = config.pressure_window_seconds
  local active = to_uint(type(record) == "table" and record.active_seconds)
  local inactive = to_uint(type(record) == "table" and record.inactive_seconds)
  local total = active + inactive
  local seeded_active = total > 0 and clamp(floor(active / total * capacity + 0.5), 0, capacity) or 0

  for index = 1, capacity do
    local previous = floor((index - 1) * seeded_active / capacity)
    local current = floor(index * seeded_active / capacity)
    push_recent(current > previous, 1)
  end
end

local function pressure_percent()
  if recent_seconds == 0 then
    return 0
  end
  return clamp(floor(recent_active / recent_seconds * 100 + 0.5), 0, 100)
end

local function get_highlight(name)
  if type(name) ~= "string" or name == "" then
    return {}
  end

  if type(api.nvim_get_hl) == "function" then
    local ok, value = pcall(api.nvim_get_hl, 0, { name = name, link = false })
    if ok and type(value) == "table" then
      return value
    end
  end

  if type(api.nvim_get_hl_by_name) == "function" then
    local ok, value = pcall(api.nvim_get_hl_by_name, name, true)
    if ok and type(value) == "table" then
      return { fg = value.foreground, bg = value.background, sp = value.special }
    end
  end

  return {}
end

local visual_modes = { v = true, V = true, ["\22"] = true, s = true, S = true, ["\19"] = true }

local function lualine_mode_name()
  local mode = (api.nvim_get_mode().mode or ""):sub(1, 1)
  if mode == "i" then
    return "insert"
  elseif visual_modes[mode] then
    return "visual"
  elseif mode == "R" or mode == "r" then
    return "replace"
  elseif mode == "c" then
    return "command"
  elseif mode == "t" then
    return "terminal"
  end
  return "normal"
end

local function current_highlight_context()
  local source = config.pressure_bar.background_highlight
  if type(source) == "function" then
    return nil
  end
  if source == "auto" then
    return table.concat({ source, lualine_mode_name(), package.loaded.lualine and "1" or "0" }, "|")
  end
  return tostring(source)
end

local function resolve_pressure_background()
  local source = config.pressure_bar.background_highlight
  if type(source) == "function" then
    local ok, value = pcall(source)
    source = ok and value or "StatusLine"
  end

  local candidates = {}
  if source == "auto" then
    local section = tostring(config.pressure_bar.lualine_section or "c"):lower():match("[abcxyz]")
    if section and package.loaded.lualine then
      candidates[#candidates + 1] = "lualine_" .. section .. "_" .. lualine_mode_name()
    end
    candidates[#candidates + 1] = "StatusLine"
    candidates[#candidates + 1] = "Normal"
  elseif type(source) == "string" and source ~= "" and source ~= "NONE" then
    candidates = { source, "StatusLine", "Normal" }
  else
    return { group = "NONE", bg = "NONE", ctermbg = "NONE" }
  end

  for _, name in ipairs(candidates) do
    local value = get_highlight(name)
    if value.bg ~= nil or value.ctermbg ~= nil then
      return { group = name, bg = value.bg, ctermbg = value.ctermbg }
    end
  end

  return { group = candidates[1] or "NONE", bg = "NONE", ctermbg = "NONE" }
end

local function signature_value(value)
  return value == nil and "nil" or tostring(value)
end

local function color_signature(spec)
  return table.concat({
    signature_value(spec.fg),
    signature_value(spec.bg),
    signature_value(spec.ctermfg),
    signature_value(spec.ctermbg),
    signature_value(spec.bold),
    signature_value(spec.italic),
  }, ":")
end

local function set_pressure_highlight(name, spec, background)
  pcall(api.nvim_set_hl, 0, name, {
    fg = spec.fg,
    bg = spec.bg ~= nil and spec.bg or background.bg,
    ctermfg = spec.ctermfg,
    ctermbg = spec.ctermbg ~= nil and spec.ctermbg or background.ctermbg,
    bold = spec.bold,
    italic = spec.italic,
    nocombine = true,
  })
end

local function install_highlights(force)
  local context = current_highlight_context()
  if not force and context and context == highlight_context and highlight_resolved then
    return
  end

  local background = resolve_pressure_background()
  local colors = config.pressure_bar.colors
  local signature = table.concat({
    background.group,
    signature_value(background.bg),
    signature_value(background.ctermbg),
    color_signature(colors.low),
    color_signature(colors.medium),
    color_signature(colors.high),
    color_signature(colors.empty),
  }, "|")

  local source = config.pressure_bar.background_highlight
  highlight_resolved = true

  if source == "auto" and package.loaded.lualine then
    local section = tostring(config.pressure_bar.lualine_section or "c"):lower():match("[abcxyz]")
    if section then
      highlight_resolved = background.group == "lualine_" .. section .. "_" .. lualine_mode_name()
    end
  elseif type(source) == "string" and source ~= "" and source ~= "NONE" then
    highlight_resolved = background.group == source
  elseif type(source) == "function" then
    highlight_resolved = false
  end

  restore_highlight = background.group
  highlight_context = context

  if not force and signature == highlight_signature then
    return
  end

  highlight_signature = signature
  set_pressure_highlight("ActiveClockPressureLow", colors.low, background)
  set_pressure_highlight("ActiveClockPressureMedium", colors.medium, background)
  set_pressure_highlight("ActiveClockPressureHigh", colors.high, background)
  set_pressure_highlight("ActiveClockPressureEmpty", colors.empty, background)
end

local function pressure_highlight(percent)
  local thresholds = config.pressure_thresholds
  if percent < thresholds.low then
    return "ActiveClockPressureLow"
  elseif percent < thresholds.high then
    return "ActiveClockPressureMedium"
  end
  return "ActiveClockPressureHigh"
end

local function pressure_bar()
  install_highlights(false)

  local percent = pressure_percent()
  local bar = config.pressure_bar
  local filled_count = clamp(floor(percent * bar.width / 100 + 0.5), 0, bar.width)
  local filled_hl = pressure_highlight(percent)
  local breakdown = ""

  if config.show_pressure_window_breakdown then
    breakdown = string.format(
      " %s Active:%s Idle:%s",
      format_duration_short(config.pressure_window_seconds),
      format_time(recent_active),
      format_time(recent_seconds - recent_active)
    )
  end

  local restore = restore_highlight ~= "NONE" and ("%#" .. restore_highlight .. "#") or "%*"

  return "%#ActiveClockPressureEmpty#["
    .. "%#" .. filled_hl .. "#"
    .. string.rep(bar.filled, filled_count)
    .. "%#ActiveClockPressureEmpty#"
    .. string.rep(bar.empty, bar.width - filled_count)
    .. "] "
    .. "%#" .. filled_hl .. "#"
    .. string.format("%3d", percent)
    .. "%%"
    .. "%#ActiveClockPressureEmpty#"
    .. breakdown
    .. restore
end

local function is_idle()
  return uv.now() - last_activity >= config.idle_seconds * 1000
end

local function process_elapsed()
  if not running then
    return 0
  end

  local current = uv.now()
  if current < last_tick then
    last_tick = current
    return 0
  end

  local elapsed = floor((current - last_tick) / 1000)
  if elapsed <= 0 then
    return 0
  end

  local interval_start = last_tick
  last_tick = last_tick + elapsed * 1000

  local active = clamp(
    floor((last_activity + config.idle_seconds * 1000 - interval_start) / 1000),
    0,
    elapsed
  )
  local inactive = elapsed - active
  local wall_start = os.time() - elapsed

  add_record_seconds(wall_start, active, "active_seconds")
  add_record_seconds(wall_start + active, inactive, "inactive_seconds")
  push_recent(true, active)
  push_recent(false, inactive)

  return elapsed
end

local function touch()
  if running then
    process_elapsed()
    last_activity = uv.now()
  end
end

local function redraw_status()
  if refresh_pending then
    return
  end

  refresh_pending = true
  vim.schedule(function()
    refresh_pending = false

    local lualine = package.loaded.lualine
    if type(lualine) == "table" and type(lualine.refresh) == "function" then
      local ok = pcall(lualine.refresh, {
        force = true,
        scope = "all",
        place = { "statusline" },
      })
      if ok then
        return
      end
    end

    if type(api.nvim__redraw) == "function" then
      local ok = pcall(api.nvim__redraw, { statusline = true, flush = true })
      if ok then
        return
      end
    end

    pcall(vim.cmd, "redrawstatus!")
  end)
end

local function json_encode(value)
  return vim.json and vim.json.encode and vim.json.encode(value) or fn.json_encode(value)
end

local function json_decode(value)
  return vim.json and vim.json.decode and vim.json.decode(value) or fn.json_decode(value)
end

local function ensure_save_directory()
  local ok, result = pcall(fn.mkdir, fn.fnamemodify(config.save_file, ":h"), "p")
  return ok and result ~= -1
end

local function read_saved_records()
  if fn.filereadable(config.save_file) ~= 1 then
    return nil, "没有找到存档"
  end

  local ok, lines = pcall(fn.readfile, config.save_file)
  if not ok then
    return nil, "读取存档失败：" .. tostring(lines)
  end

  local decoded
  ok, decoded = pcall(json_decode, table.concat(lines, "\n"))
  if not ok then
    return nil, "存档 JSON 无法解析：" .. tostring(decoded)
  end

  if type(decoded) ~= "table" or tonumber(decoded.version) ~= 2 or type(decoded.records) ~= "table" then
    return nil, "存档格式无效，需要 version = 2 的每日记录格式"
  end

  local loaded = {}
  for day, record in pairs(decoded.records) do
    if type(day) ~= "string" or not day:match("^%d%d%d%d%-%d%d%-%d%d$") or type(record) ~= "table" then
      return nil, "存档中存在无效的每日记录"
    end

    local active = tonumber(record.active_seconds)
    local inactive = tonumber(record.inactive_seconds)
    if not active or active < 0 or not inactive or inactive < 0 then
      return nil, "存档中 " .. day .. " 的时间数据无效"
    end

    loaded[day] = {
      active_seconds = floor(active),
      inactive_seconds = floor(inactive),
      updated_at = floor(tonumber(record.updated_at) or 0),
    }
  end

  return loaded
end

local function stop_timer()
  local handle = timer
  timer = nil

  if handle and not handle:is_closing() then
    handle:stop()
    handle:close()
  end
end

local function start_timer()
  stop_timer()

  local handle = uv.new_timer()
  timer = handle
  handle:start(1000, 1000, vim.schedule_wrap(function()
    if timer ~= handle or handle:is_closing() then
      return
    end
    process_elapsed()
    redraw_status()
  end))
end

local function install_input_listener()
  vim.on_key(nil, input_namespace)
  vim.on_key(function(key, typed)
    key, typed = key or "", typed or ""

    if terminal_mode then
      if key ~= "" or typed ~= "" then
        touch()
      end
    elseif typed ~= "" or (not supports_typed_key and key ~= "") then
      touch()
    end
  end, input_namespace)
end

local function install_autocmds()
  local group = api.nvim_create_augroup("ActiveClock", { clear = true })
  local function on_activity()
    touch()
    redraw_status()
  end

  api.nvim_create_autocmd("TermEnter", {
    group = group,
    callback = function()
      terminal_mode = true
      on_activity()
    end,
  })

  api.nvim_create_autocmd("TermLeave", {
    group = group,
    callback = function()
      terminal_mode = false
      on_activity()
    end,
  })

  api.nvim_create_autocmd({ "FocusGained", "BufEnter", "WinEnter" }, {
    group = group,
    callback = on_activity,
  })

  api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      highlight_signature, highlight_context, highlight_resolved = nil, nil, false
      install_highlights(true)
      redraw_status()
    end,
  })

  api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.save({ silent = true })
      stop_timer()
      vim.on_key(nil, input_namespace)
    end,
  })
end

local function install_commands()
  local commands = {
    ActiveClockStart = { "start", "开始 ActiveClock 计时" },
    ActiveClockStop = { "stop", "停止 ActiveClock 计时" },
    ActiveClockSave = { "save", "保存 ActiveClock 每日记录" },
    ActiveClockReload = { "reload", "从存档重新加载 ActiveClock 每日记录" },
    ActiveClockReset = { "reset", "只重置 ActiveClock 今天的记录" },
  }

  for name, spec in pairs(commands) do
    local method, description = spec[1], spec[2]
    pcall(api.nvim_del_user_command, name)
    api.nvim_create_user_command(name, function()
      M[method]()
    end, { desc = description, nargs = 0 })
  end
end

local function positive_integer(value, fallback)
  return max(1, floor(tonumber(value) or fallback))
end

local function normalize_color(name)
  local colors = config.pressure_bar.colors
  colors[name] = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(defaults.pressure_bar.colors[name]),
    type(colors[name]) == "table" and colors[name] or {}
  )
end

local function normalize_config(opts)
  config = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(defaults),
    type(opts) == "table" and opts or {}
  )

  config.idle_seconds = positive_integer(config.idle_seconds, defaults.idle_seconds)
  config.pressure_window_seconds = positive_integer(
    config.pressure_window_seconds,
    defaults.pressure_window_seconds
  )

  if type(config.show_pressure_window_breakdown) ~= "boolean" then
    config.show_pressure_window_breakdown = defaults.show_pressure_window_breakdown
  end

  if type(config.pressure_bar) ~= "table" then
    config.pressure_bar = vim.deepcopy(defaults.pressure_bar)
  end

  local bar = config.pressure_bar
  bar.width = positive_integer(bar.width, defaults.pressure_bar.width)
  bar.filled = type(bar.filled) == "string" and bar.filled ~= "" and bar.filled or defaults.pressure_bar.filled
  bar.empty = type(bar.empty) == "string" and bar.empty ~= "" and bar.empty or defaults.pressure_bar.empty

  if type(bar.background_highlight) ~= "string" and type(bar.background_highlight) ~= "function" then
    bar.background_highlight = defaults.pressure_bar.background_highlight
  end

  local section = type(bar.lualine_section) == "string" and bar.lualine_section:lower() or ""
  bar.lualine_section = section:match("^[abcxyz]$") and section or defaults.pressure_bar.lualine_section

  if type(bar.colors) ~= "table" then
    bar.colors = vim.deepcopy(defaults.pressure_bar.colors)
  end
  normalize_color("low")
  normalize_color("medium")
  normalize_color("high")
  normalize_color("empty")

  if type(config.pressure_thresholds) ~= "table" then
    config.pressure_thresholds = vim.deepcopy(defaults.pressure_thresholds)
  end

  local low = clamp(floor(tonumber(config.pressure_thresholds.low) or defaults.pressure_thresholds.low), 0, 100)
  local high = clamp(floor(tonumber(config.pressure_thresholds.high) or defaults.pressure_thresholds.high), 0, 100)
  if high <= low then
    low, high = defaults.pressure_thresholds.low, defaults.pressure_thresholds.high
  end
  config.pressure_thresholds.low, config.pressure_thresholds.high = low, high

  if type(config.frames) ~= "table" or #config.frames == 0 then
    config.frames = vim.deepcopy(defaults.frames)
  end
  if type(config.idle_frame) ~= "string" or config.idle_frame == "" then
    config.idle_frame = defaults.idle_frame
  end
  if type(config.save_file) ~= "string" or config.save_file == "" then
    config.save_file = defaults.save_file
  end
end

function M.start(opts)
  opts = opts or {}
  if running then
    if not opts.silent then
      notify("计时已经在运行")
    end
    return false
  end

  local current = uv.now()
  last_activity, last_tick = current, current
  running = true
  start_timer()
  redraw_status()

  if not opts.silent then
    notify("已开始计时")
  end
  return true
end

function M.stop(opts)
  opts = opts or {}
  if not running then
    if not opts.silent then
      notify("计时已经停止")
    end
    return false
  end

  process_elapsed()
  running = false
  stop_timer()

  local saved = M.save({ silent = true })
  redraw_status()

  if not opts.silent then
    local record = get_today_record()
    local message = string.format(
      "已停止计时：active %s / inactive %s%s",
      format_time(record.active_seconds),
      format_time(record.inactive_seconds),
      saved and "" or "（自动保存失败）"
    )
    notify(message, saved and vim.log.levels.INFO or vim.log.levels.ERROR)
  end

  return true
end

function M.is_running()
  return running
end

function M.save(opts)
  opts = opts or {}
  process_elapsed()
  get_today_record()

  if not ensure_save_directory() then
    if not opts.silent then
      notify("无法创建存档目录", vim.log.levels.ERROR)
    end
    return false
  end

  local ok, encoded = pcall(json_encode, {
    version = 2,
    records = records,
    saved_at = os.time(),
  })

  if not ok then
    if not opts.silent then
      notify("生成存档失败：" .. tostring(encoded), vim.log.levels.ERROR)
    end
    return false
  end

  local result
  ok, result = pcall(fn.writefile, { encoded }, config.save_file)
  if not ok or result ~= 0 then
    if not opts.silent then
      notify("写入存档失败：" .. config.save_file, vim.log.levels.ERROR)
    end
    return false
  end

  if not opts.silent then
    local record = get_today_record()
    notify(string.format(
      "已保存今天：active %s / inactive %s",
      format_time(record.active_seconds),
      format_time(record.inactive_seconds)
    ))
  end

  return true
end

function M.reload(opts)
  opts = opts or {}
  local loaded, err = read_saved_records()

  if not loaded then
    if not opts.silent then
      notify(err, vim.log.levels.WARN)
    end
    return false
  end

  records = loaded
  local record = get_today_record()
  seed_recent(record)

  local current = uv.now()
  last_activity, last_tick = current, current
  redraw_status()

  if not opts.silent then
    notify(string.format(
      "已重新加载今天：active %s / inactive %s",
      format_time(record.active_seconds),
      format_time(record.inactive_seconds)
    ))
  end

  return true
end

function M.reset(opts)
  opts = opts or {}
  process_elapsed()

  local today = date_key()
  records[today] = { active_seconds = 0, inactive_seconds = 0, updated_at = os.time() }
  seed_recent(records[today])

  local current = uv.now()
  last_activity, last_tick = current, current
  redraw_status()

  if not M.save({ silent = true }) then
    if not opts.silent then
      notify("今天的计时已重置，但写入存档失败：" .. config.save_file, vim.log.levels.ERROR)
    end
    return false
  end

  if not opts.silent then
    notify("今天的 active/inactive 记录已重置，历史记录已保留")
  end
  return true
end

function M.component()
  process_elapsed()
  local record = get_today_record()
  local character

  if not running then
    character = "⏸"
  elseif is_idle() then
    character = config.idle_frame
  else
    character = config.frames[floor(record.active_seconds / 2) % #config.frames + 1]
  end

  return string.format(
    "%s A:%s I:%s %s",
    character,
    format_time(record.active_seconds),
    format_time(record.inactive_seconds),
    pressure_bar()
  )
end

function M.pressure_component()
  process_elapsed()
  return pressure_bar()
end

local function get_today_field(field)
  process_elapsed()
  return get_today_record()[field]
end

function M.get_active_seconds()
  return get_today_field("active_seconds")
end

M.get_seconds = M.get_active_seconds

function M.get_inactive_seconds()
  return get_today_field("inactive_seconds")
end

function M.get_pressure_percent()
  process_elapsed()
  return pressure_percent()
end

function M.get_today_record()
  process_elapsed()
  return vim.deepcopy(get_today_record())
end

function M.get_records()
  process_elapsed()
  return vim.deepcopy(records)
end

function M.get_save_file()
  return config.save_file
end

function M.setup(opts)
  normalize_config(opts)
  clear_recent()
  running = true
  highlight_signature, highlight_context, highlight_resolved = nil, nil, false
  terminal_mode = (api.nvim_get_mode().mode or ""):sub(1, 1) == "t"

  install_input_listener()
  install_autocmds()
  install_commands()

  local loaded = config.auto_load and M.reload({ silent = true }) or false
  if not loaded then
    local current = uv.now()
    last_activity, last_tick = current, current
    seed_recent(get_today_record())
  end

  install_highlights(true)
  touch()
  start_timer()
  redraw_status()
  return M
end

return M
