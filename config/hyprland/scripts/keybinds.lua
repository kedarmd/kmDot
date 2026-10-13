#!/usr/bin/env lua

local file = arg[1]
if not file then
  io.stderr:write("usage: keybinds.lua <keybinds.lua>\n")
  os.exit(1)
end

local lines = {}
for line in io.lines(file) do
  lines[#lines + 1] = line
end

local binds = {}

local function proxy(path)
  return setmetatable({}, {
    __index = function(_, member)
      return proxy(path == "" and member or path .. "." .. member)
    end,
    __call = function(_, ...)
      return { path = path, args = { ... } }
    end,
  })
end

hl = {
  dsp = proxy(""),
}

hl.bind = function(key, action, _)
  local info = debug.getinfo(2, "l")
  binds[#binds + 1] = { key = key, line = info.currentline, action = action }
end

local chunk = assert(loadfile(file))
chunk()

local function trailing_comment(text)
  local comment = text:match("%-%-%s*(.-)%s*$")
  return comment
end

local function action_target(action)
  if not action then
    return ""
  end

  if action.path == "exec_cmd" then
    local command = tostring(action.args[1] or "")
    local target = command:match("toggle%.sh%s+([%w%-_]+)")
    if target then
      return target
    end
    if command:match("launcher%.sh") then
      return "kmdot-launcher"
    end
    if command ~= "" then
      return "exec:" .. command
    end
  end

  if action.path == "exit" then
    return "dsp:exit"
  end
  return ""
end

for _, b in ipairs(binds) do
  local start = b.line
  local depth = 0
  local comment = nil

  for i = start, #lines do
    local text = lines[i]
    local in_string = false
    local quote = nil

    for j = 1, #text do
      local c = text:sub(j, j)

      if in_string then
        if c == "\\" then
          c = text:sub(j + 1, j + 1)
          if c == "" then
            break
          end
          if c == quote then
            in_string = false
          end
        elseif c == quote then
          in_string = false
        end
      elseif c == '"' or c == "'" then
        in_string = true
        quote = c
      elseif c == "(" then
        depth = depth + 1
      elseif c == ")" then
        depth = depth - 1
        if depth == 0 then
          comment = trailing_comment(text:sub(j + 1))
          break
        end
      end
    end

    if depth == 0 then
      break
    end
  end

  print(b.key .. "\t" .. (comment or "") .. "\t" .. action_target(b.action))
end
