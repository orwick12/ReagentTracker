local ns = load_addon("Data.lua", "Logic.lua")
local D, L = ns.Data, ns.Logic

local MH = { key = "weapon_mh", kind = "weapon", slot = "mh", label = "MH" }
local MIN = 60000

local function buff(ms, charges, id) return { equipped = true, buff = { enchantID = id or 323, remainingMs = ms, charges = charges } } end

local function byKey(lines, key)
  for _, l in ipairs(lines) do if l.key == key then return l end end
end

test("format time", function()
  eq(L.FormatTime(1417700), "23m")
  eq(L.FormatTime(59999), "59s")
  eq(L.FormatTime(60000), "1m")
end)

test("healthy poison", function()
  eq(L.WeaponLine(MH, buff(1417700, 59), D),
    { key = "weapon_mh", label = "MH Instant Poison", value = "23m 59", color = "white" })
end)

test("missing buff red", function()
  eq(L.WeaponLine(MH, { equipped = true }, D), { key = "weapon_mh", label = "MH", value = "NO BUFF", color = "red" })
end)

test("no off-hand weapon, no line", function()
  eq(L.WeaponLine(MH, { equipped = false }, D), nil)
  local s = { class = "ROGUE", level = 22, known = {}, counts = {},
    weapons = { mh = buff(30 * MIN, 59), oh = { equipped = false } } }
  local lines = L.BuildLines(D, s, { toggles = {} })
  eq(byKey(lines, "weapon_oh"), nil)
  eq(byKey(lines, "weapon_mh").color, "white")
end)

test("time boundaries", function()
  eq(L.WeaponLine(MH, buff(5 * MIN, 59), D).color, "yellow")
  eq(L.WeaponLine(MH, buff(5 * MIN - 1, 59), D).color, "red")
  eq(L.WeaponLine(MH, buff(10 * MIN, 59), D).color, "white")
  eq(L.WeaponLine(MH, buff(10 * MIN - 1, 59), D).color, "yellow")
end)

test("charge boundaries", function()
  eq(L.WeaponLine(MH, buff(30 * MIN, 20), D).color, "white")
  eq(L.WeaponLine(MH, buff(30 * MIN, 19), D).color, "yellow")
  eq(L.WeaponLine(MH, buff(30 * MIN, 5), D).color, "yellow")
  eq(L.WeaponLine(MH, buff(30 * MIN, 4), D).color, "red")
end)

test("worst of time and charges wins", function()
  eq(L.WeaponLine(MH, buff(4 * MIN, 59), D).color, "red")
  eq(L.WeaponLine(MH, buff(8 * MIN, 3), D).color, "red")
end)

test("no-charge buff judged on time only", function()
  eq(L.WeaponLine(MH, buff(30 * MIN, 0), D), { key = "weapon_mh", label = "MH Instant Poison", value = "30m", color = "white" })
  eq(L.WeaponLine(MH, buff(30 * MIN, nil), D).value, "30m")
end)

test("unknown enchant labelled Buff", function()
  eq(L.WeaponLine(MH, buff(30 * MIN, 0, 99999), D).label, "MH Buff")
end)

test("weapon lines default off for mage, on for shaman", function()
  local function s(class)
    return { class = class, level = 30, known = {}, counts = {}, weapons = { mh = { equipped = true }, oh = { equipped = false } } }
  end
  eq(byKey(L.BuildLines(D, s("MAGE"), { toggles = {} }), "weapon_mh"), nil)
  eq(byKey(L.BuildLines(D, s("SHAMAN"), { toggles = {} }), "weapon_mh").value, "NO BUFF")
end)
