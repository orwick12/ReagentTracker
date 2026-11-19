-- Minimal test runner. Run from the repo root: luajit tests/run.lua
-- Loads addon files the way WoW does (each file receives addonName, ns via ...).

local ADDON_DIR = "ReagentTracker/"

function load_addon(...)
  local ns = {}
  for i = 1, select("#", ...) do
    local file = select(i, ...)
    local chunk, err = loadfile(ADDON_DIR .. file)
    if not chunk then error(err, 2) end
    chunk("ReagentTracker", ns)
  end
  return ns
end

local function show(v)
  if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. show(v[k]) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function eq(actual, expected, msg)
  if not deepEqual(actual, expected) then
    error((msg and (msg .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
  end
end

function ok(cond, msg)
  if not cond then error(msg or "assertion failed", 2) end
end

local tests = {}
function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local files = {}
local p = io.popen("ls tests/test_*.lua 2>/dev/null")
for line in p:lines() do files[#files + 1] = line end
p:close()

local passed, failed = 0, 0
for _, f in ipairs(files) do
  tests = {}
  local chunk, err = loadfile(f)
  if not chunk then
    print("FAIL " .. f .. ": " .. err); failed = failed + 1
  else
    local okLoad, loadErr = pcall(chunk)
    if not okLoad then print("FAIL " .. f .. " (load): " .. tostring(loadErr)); failed = failed + 1 end
    for _, t in ipairs(tests) do
      local okRun, runErr = pcall(t.fn)
      if okRun then passed = passed + 1; print("PASS " .. t.name)
      else failed = failed + 1; print("FAIL " .. t.name .. ": " .. tostring(runErr)) end
    end
  end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
