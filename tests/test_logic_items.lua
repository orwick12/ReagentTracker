local ns = load_addon("Data.lua", "Logic.lua")
local D, L = ns.Data, ns.Logic

local function snap(t)
  t.class = t.class or "ROGUE"
  t.level = t.level or 22
  t.known = t.known or {}
  t.counts = t.counts or {}
  t.weapons = t.weapons or { mh = { equipped = false }, oh = { equipped = false } }
  return t
end

local function settings(t) t = t or {}; t.toggles = t.toggles or {}; return t end

local function byKey(lines, key)
  for _, l in ipairs(lines) do if l.key == key then return l end end
end

local function entry(class, key)
  for _, e in ipairs(D.classes[class].entries) do if e.key == key then return e end end
end

test("count colors", function()
  eq(L.ColorForCount(0, 5), "red")
  eq(L.ColorForCount(4, 5), "yellow")
  eq(L.ColorForCount(5, 5), "white")
  eq(L.ColorForCount(0, 0), "red")
  eq(L.ColorForCount(1, 0), "white")
  eq(L.ColorForCount(3, nil), "yellow")
end)

test("untrained spell entry hidden", function()
  local lines = L.BuildLines(D, snap({}), settings())
  eq(byKey(lines, "flash_powder"), nil)
  eq(L.EntryStatus(entry("ROGUE", "flash_powder"), snap({})), "untrained")
end)

test("known spell shows summed count", function()
  local lines = L.BuildLines(D, snap({ known = { [1856] = true }, counts = { [5140] = 40 } }), settings())
  eq(byKey(lines, "flash_powder"), { key = "flash_powder", label = "Flash Powder", value = "40", color = "white" })
end)

test("poison ranks summed and level gated", function()
  local s = snap({ counts = { [6947] = 10, [6949] = 6, [2892] = 5 } })
  local lines = L.BuildLines(D, s, settings())
  eq(byKey(lines, "instant_poison").value, "16")
  eq(byKey(lines, "deadly_poison"), nil)
  local status, detail = L.EntryStatus(entry("ROGUE", "deadly_poison"), s)
  eq({ status, detail }, { "level", 30 })
  eq(L.EntryStatus(entry("ROGUE", "instant_poison"), s), "active")
end)

test("level gate is inclusive", function()
  eq(L.EntryStatus(entry("ROGUE", "deadly_poison"), snap({ level = 30 })), "active")
  eq(L.EntryStatus(entry("ROGUE", "instant_poison"), snap({ level = 19 })), "level")
end)

test("missing reagent is red zero", function()
  local lines = L.BuildLines(D, snap({ known = { [1856] = true } }), settings())
  eq(byKey(lines, "flash_powder").value, "0")
  eq(byKey(lines, "flash_powder").color, "red")
end)

test("druid highest tier wins", function()
  local s = snap({ class = "DRUID", level = 30, known = { [20484] = true, [20739] = true }, counts = { [17035] = 1 } })
  local lines = L.BuildLines(D, s, settings())
  eq(byKey(lines, "rebirth_seed"), { key = "rebirth_seed", label = "Stranglethorn Seed", value = "1", color = "yellow" })
end)

test("druid with no rebirth rank has no seed line", function()
  local s = snap({ class = "DRUID", level = 10 })
  eq(byKey(L.BuildLines(D, s, settings()), "rebirth_seed"), nil)
  eq(L.EntryStatus(entry("DRUID", "rebirth_seed"), s), "untrained")
end)

test("hunter ammo", function()
  local lines = L.BuildLines(D, snap({ class = "HUNTER", ammo = 150 }), settings())
  eq(byKey(lines, "ammo"), { key = "ammo", label = "Ammo", value = "150", color = "yellow" })
  eq(byKey(L.BuildLines(D, snap({ class = "HUNTER" }), settings()), "ammo"), nil)
  eq(L.EntryStatus(entry("HUNTER", "ammo"), snap({ class = "HUNTER" })), "unavailable")
end)

test("toggle off hides line", function()
  local s = snap({ counts = { [6947] = 16 } })
  local lines = L.BuildLines(D, s, settings({ toggles = { instant_poison = false } }))
  eq(byKey(lines, "instant_poison"), nil)
end)

test("toggle on overrides weapon default", function()
  local mh = entry("MAGE", "weapon_mh")
  eq(L.IsEnabled("MAGE", mh, settings(), D), false)
  eq(L.IsEnabled("MAGE", mh, settings({ toggles = { weapon_mh = true } }), D), true)
  eq(L.IsEnabled("ROGUE", entry("ROGUE", "weapon_mh"), settings(), D), true)
  eq(L.IsEnabled("ROGUE", entry("ROGUE", "weapon_mh"), settings({ toggles = { weapon_mh = false } }), D), false)
  eq(L.IsEnabled("ROGUE", entry("ROGUE", "flash_powder"), settings(), D), true)
end)

test("problemsOnly drops white lines", function()
  local s = snap({ known = { [1856] = true }, counts = { [5140] = 40, [6947] = 2 } })
  local lines = L.BuildLines(D, s, settings({ problemsOnly = true }))
  eq(byKey(lines, "flash_powder"), nil)
  eq(byKey(lines, "instant_poison").color, "yellow")
  eq(byKey(lines, "crippling_poison").color, "red")
end)

test("lines follow data order", function()
  local s = snap({ known = { [1856] = true } })
  local keys = {}
  for _, l in ipairs(L.BuildLines(D, s, settings())) do keys[#keys + 1] = l.key end
  eq(keys, { "flash_powder", "instant_poison", "crippling_poison" })
end)

test("warrior and unknown class produce no lines", function()
  eq(L.BuildLines(D, snap({ class = "WARRIOR" }), settings()), {})
  eq(L.BuildLines(D, snap({ class = "EVOKER" }), settings()), {})
end)
