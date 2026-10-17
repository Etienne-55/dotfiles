-- Treesitter-powered "entry logs" on top of chainsaw (JS/TS family).
-- Inserts `console.log('🪚 Class.method', { arg1, arg2 });` as the first line of
-- a function body, using chainsaw's marker so `removeLogs()` and the signs still work.

local FUNC_TYPES = {
  method_definition = true,
  function_declaration = true,
  generator_function_declaration = true,
  function_expression = true,
  ["function"] = true,
  arrow_function = true,
}
local CLASS_TYPES = { class_declaration = true, abstract_class_declaration = true, class = true }

local function text(node) return node and vim.treesitter.get_node_text(node, 0) or nil end

local function funcName(fn)
  local name = text(fn:field("name")[1])
  if not name then
    local p = fn:parent()
    local pt = p and p:type()
    if pt == "variable_declarator" or pt == "public_field_definition" then
      name = text(p:field("name")[1])
    elseif pt == "field_definition" then
      name = text(p:field("property")[1])
    elseif pt == "pair" then
      name = text(p:field("key")[1])
    elseif pt == "assignment_expression" then
      name = text(p:field("left")[1])
    end
  end
  if not name then return nil end
  name = name:gsub("['\"`]", "")

  -- prefix the enclosing class, unless we are nested in another function
  local anc = fn:parent()
  while anc and not FUNC_TYPES[anc:type()] do
    if CLASS_TYPES[anc:type()] then
      local cls = text(anc:field("name")[1])
      if cls then name = cls .. "." .. name end
      break
    end
    anc = anc:parent()
  end
  return name
end

-- collects identifiers bound by a parameter pattern (handles destructuring, defaults, rest)
local function collectBindings(node, out)
  local t = node:type()
  if t == "identifier" or t == "shorthand_property_identifier_pattern" then
    table.insert(out, text(node))
  elseif t == "required_parameter" or t == "optional_parameter" then
    local pat = node:field("pattern")[1]
    if pat then collectBindings(pat, out) end
  elseif t == "assignment_pattern" or t == "object_assignment_pattern" then
    local left = node:field("left")[1]
    if left then collectBindings(left, out) end
  elseif t == "pair_pattern" then
    local value = node:field("value")[1]
    if value then collectBindings(value, out) end
  elseif t == "object_pattern" or t == "array_pattern" or t == "rest_pattern" then
    for child in node:iter_children() do
      if child:named() then collectBindings(child, out) end
    end
  end
end

local function paramNames(fn)
  local out = {}
  local single = fn:field("parameter")[1] -- `x => …`
  if single then
    collectBindings(single, out)
    return out
  end
  local params = fn:field("parameters")[1]
  if not params then return out end
  for child in params:iter_children() do
    if child:named() then collectBindings(child, out) end
  end
  return out
end

local function indentUnit()
  return vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t"
end

---@return boolean inserted
local function insertEntryLog(fn, allowAnonymous)
  local body = fn:field("body")[1]
  if not body or body:type() ~= "statement_block" then return false end
  local startRow, _, endRow = body:range()
  if startRow == endRow then return false end -- `{}` on one line

  local marker = require("chainsaw.config.config").config.marker
  local nextLine = vim.api.nvim_buf_get_lines(0, startRow + 1, startRow + 2, false)[1] or ""
  if nextLine:find(marker, 1, true) then return false end -- already instrumented

  local name = funcName(fn)
  if not name then
    if not allowAnonymous then return false end
    name = "anonymous:" .. (startRow + 1)
  end

  local params = paramNames(fn)
  local args = #params > 0 and (", { " .. table.concat(params, ", ") .. " }") or ""

  local indent
  local first = body:named_child(0)
  if first and first:start() > startRow then
    indent = vim.api.nvim_buf_get_lines(0, first:start(), first:start() + 1, false)[1]:match("^%s*")
  else
    local braceLine = vim.api.nvim_buf_get_lines(0, startRow, startRow + 1, false)[1]
    indent = braceLine:match("^%s*") .. indentUnit()
  end

  local line = ("%sconsole.log('%s %s'%s);"):format(indent, marker, name, args)
  vim.api.nvim_buf_set_lines(0, startRow + 1, startRow + 1, false, { line })
  require("chainsaw.visuals.styling").addStylingToLine(startRow + 1)
  return true
end

local function getRoot()
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not ok or not parser then
    vim.notify("No treesitter parser for this buffer", vim.log.levels.WARN, { title = "chainsaw" })
    return nil
  end
  return parser:parse()[1]:root()
end

-- log entry of the function under the cursor
local function logFunctionEntry()
  if not getRoot() then return end
  local node = vim.treesitter.get_node()
  while node do
    if FUNC_TYPES[node:type()] and node:field("body")[1] and node:field("body")[1]:type() == "statement_block" then
      if not insertEntryLog(node, true) then
        vim.notify("Function already logged (or one-line body)", vim.log.levels.INFO, { title = "chainsaw" })
      end
      return
    end
    node = node:parent()
  end
  vim.notify("No function under cursor", vim.log.levels.WARN, { title = "chainsaw" })
end

-- log entry of every named function/method in the buffer
local function logAllFunctions()
  local root = getRoot()
  if not root then return end
  local fns = {}
  local function walk(node)
    if FUNC_TYPES[node:type()] then table.insert(fns, node) end
    for child in node:iter_children() do
      if child:named() then walk(child) end
    end
  end
  walk(root)
  -- bottom-up so earlier node ranges stay valid
  table.sort(fns, function(a, b) return a:start() > b:start() end)
  local count = 0
  for _, fn in ipairs(fns) do
    if insertEntryLog(fn, false) then count = count + 1 end
  end
  vim.notify(("Logged %d functions"):format(count), vim.log.levels.INFO, { title = "chainsaw" })
end

return {
  "chrisgrieser/nvim-chainsaw",
  opts = {
    logStatements = {
      -- add file:line so you know where each log comes from (applies to ts/tsx/vue/… via supersets)
      variableLog = { javascript = 'console.log("{{marker}} {{filename}}:{{lnum}} {{var}}:", {{var}});' },
      messageLog = { javascript = 'console.log("{{marker}} {{filename}}:{{lnum}} {{insert}}");' },
    },
  },
  keys = {
    -- logs the word under cursor, or the visual selection
    { "<leader>lo", function() require("chainsaw").variableLog() end, mode = { "n", "x" }, desc = "Log variable" },
    { "<leader>li", function() require("chainsaw").objectLog() end, mode = { "n", "x" }, desc = "Log object (inspect)" },
    { "<leader>ly", function() require("chainsaw").typeLog() end, mode = { "n", "x" }, desc = "Log type" },
    { "<leader>la", function() require("chainsaw").assertLog() end, mode = { "n", "x" }, desc = "Log assert" },
    { "<leader>lh", function() require("chainsaw").messageLog() end, desc = "Log 'got here'" },
    { "<leader>le", function() require("chainsaw").emojiLog() end, desc = "Log emoji (quick marker)" },
    { "<leader>lt", function() require("chainsaw").timeLog() end, desc = "Log time (start/stop)" },
    { "<leader>ls", function() require("chainsaw").stacktraceLog() end, desc = "Log stacktrace" },
    { "<leader>ld", function() require("chainsaw").debugLog() end, desc = "Insert debugger" },
    { "<leader>lf", function() logFunctionEntry() end, desc = "Log function entry + args" },
    { "<leader>lF", function() logAllFunctions() end, desc = "Log every function in file" },
    { "<leader>lr", function() require("chainsaw").removeLogs() end, desc = "Remove all logs" },
  },
}
