local ns = load_addon("Data.lua")
local D = ns.Data

local CLASSES = { "ROGUE", "MAGE", "PRIEST", "DRUID", "PALADIN", "SHAMAN", "WARLOCK", "HUNTER", "WARRIOR" }

local function find(class, key)
  for _, e in ipairs(D.classes[class].entries) do if e.key == key then return e end end
end

local function contains(list, v)
  for _, x in ipairs(list or {}) do if x == v then return true end end
  return false
end

test("all nine classes present", function()
  for _, c in ipairs(CLASSES) do ok(D.classes[c], c .. " missing") end
end)

test("every entry has key, label, and a way to unlock", function()
  for _, c in ipairs(CLASSES) do
    for i, e in ipairs(D.classes[c].entries) do
      local where = c .. " entry " .. i
      ok(type(e.key) == "string", where .. " key")
      ok(type(e.label) == "string", where .. " label")
      if e.kind ~= "weapon" then
        local ways = (e.spells and 1 or 0) + (e.level and 1 or 0) + (e.tiers and 1 or 0) + (e.kind == "ammo" and 1 or 0)
        eq(ways, 1, where .. " (" .. e.key .. ") unlock ways")
      end
    end
  end
end)

test("every class starts with MH and OH weapon entries", function()
  for _, c in ipairs(CLASSES) do
    local e = D.classes[c].entries
    eq({ e[1].key, e[1].kind, e[1].slot, e[1].label }, { "weapon_mh", "weapon", "mh", "MH" }, c)
    eq({ e[2].key, e[2].kind, e[2].slot, e[2].label }, { "weapon_oh", "weapon", "oh", "OH" }, c)
  end
end)

test("keys are unique within a class", function()
  for _, c in ipairs(CLASSES) do
    local seen = {}
    for _, e in ipairs(D.classes[c].entries) do
      ok(not seen[e.key], c .. " duplicate key " .. e.key)
      seen[e.key] = true
    end
  end
end)

test("item entries have at least one item id", function()
  for _, c in ipairs(CLASSES) do
    for _, e in ipairs(D.classes[c].entries) do
      if e.kind ~= "weapon" and e.kind ~= "ammo" and not e.tiers then
        ok(type(e.items) == "table" and #e.items > 0, c .. " " .. e.key .. " items")
      end
      if e.tiers then
        for i, t in ipairs(e.tiers) do
          ok(#t.items > 0 and #t.spells > 0 and type(t.label) == "string", c .. " " .. e.key .. " tier " .. i)
        end
      end
    end
  end
end)

test("verified rogue data", function()
  local fp = find("ROGUE", "flash_powder")
  eq(fp.items, { 5140 })
  ok(contains(fp.spells, 1856), "Vanish 1856")
  local ip = find("ROGUE", "instant_poison")
  eq(ip.level, 20); ok(contains(ip.items, 6947), "6947")
  local cp = find("ROGUE", "crippling_poison")
  eq(cp.level, 20); ok(contains(cp.items, 3775), "3775")
  eq(D.enchantNames[323], "Instant Poison")
end)

test("warrior has only weapon entries", function()
  eq(#D.classes.WARRIOR.entries, 2)
end)

test("weapon lines default on for rogue and shaman only", function()
  eq(D.weaponDefaultOn, { ROGUE = true, SHAMAN = true })
end)

test("spec values spot-check", function()
  eq(find("ROGUE", "deadly_poison").level, 30)
  eq(find("ROGUE", "wound_poison").level, 32)
  eq(find("ROGUE", "mind_numbing_poison").level, 24)
  eq(find("WARLOCK", "soul_shard").low, 3)
  eq(find("HUNTER", "ammo").low, 200)
  eq(find("HUNTER", "ammo").kind, "ammo")
  eq(find("SHAMAN", "earth_totem").low, 0)
  eq(find("DRUID", "rebirth_seed").tiers[2].label, "Stranglethorn Seed")
  eq(find("DRUID", "rebirth_seed").low, 2)
  eq(find("PALADIN", "symbol_of_kings").low, 20)
  eq(find("MAGE", "rune_of_teleportation").low, 2)
end)
