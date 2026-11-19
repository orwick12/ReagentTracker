local _, ns = ...

-- Per-class tracking data. Pure data: no WoW globals.
-- Verified in game on WoW Forever (2026-11-19): rogue Vanish 1856 -> Flash Powder 5140,
-- Instant Poison 6947, Crippling Poison 3775, enchant 323 = Instant Poison.
-- Everything else is from original Classic and unverified on Forever; run /rrt check in game.
--
-- Entry fields: key, label, items (summed), spells (any known) | level | tiers, low (default 5,
-- 0 = no yellow), kind ("item" default | "weapon" | "ammo"), slot (weapon only).

local function weapons()
  return {
    { key = "weapon_mh", kind = "weapon", slot = "mh", label = "MH" },
    { key = "weapon_oh", kind = "weapon", slot = "oh", label = "OH" },
  }
end

local function class(extra)
  local entries = weapons()
  for _, e in ipairs(extra) do entries[#entries + 1] = e end
  return { entries = entries }
end

local Data = {}

Data.weaponDefaultOn = { ROGUE = true, SHAMAN = true }

Data.classes = {
  ROGUE = class({
    { key = "flash_powder", label = "Flash Powder", items = { 5140 }, spells = { 1856, 1857 } },
    { key = "blinding_powder", label = "Blinding Powder", items = { 5530 }, spells = { 2094 } },
    { key = "instant_poison", label = "Instant Poison", level = 20,
      items = { 6947, 6949, 6950, 8926, 8927, 8928 } },
    { key = "crippling_poison", label = "Crippling Poison", level = 20, items = { 3775, 3776 } },
    { key = "mind_numbing_poison", label = "Mind-numbing Poison", level = 24, items = { 5237, 6951, 9186 } },
    { key = "deadly_poison", label = "Deadly Poison", level = 30, items = { 2892, 2893, 8984, 8985, 20844 } },
    { key = "wound_poison", label = "Wound Poison", level = 32, items = { 10918, 10920, 10921, 10922 } },
  }),

  MAGE = class({
    { key = "light_feather", label = "Light Feather", items = { 17056 }, spells = { 130 } },
    { key = "rune_of_teleportation", label = "Rune of Teleportation", items = { 17031 }, low = 2,
      spells = { 3561, 3562, 3565, 3567, 3563, 3566 } },
    { key = "rune_of_portals", label = "Rune of Portals", items = { 17032 }, low = 2,
      spells = { 10059, 11416, 11419, 11417, 11418, 11420 } },
    { key = "arcane_powder", label = "Arcane Powder", items = { 17020 }, low = 10, spells = { 23028 } },
  }),

  PRIEST = class({
    { key = "light_feather", label = "Light Feather", items = { 17056 }, spells = { 1706 } },
    { key = "holy_candle", label = "Holy Candle", items = { 17028 }, spells = { 21562 } },
    { key = "sacred_candle", label = "Sacred Candle", items = { 17029 }, spells = { 21564, 27681, 27683 } },
  }),

  DRUID = class({
    { key = "rebirth_seed", label = "Rebirth Seed", low = 2, tiers = {
      { label = "Maple Seed", items = { 17034 }, spells = { 20484 } },
      { label = "Stranglethorn Seed", items = { 17035 }, spells = { 20739 } },
      { label = "Ashwood Seed", items = { 17036 }, spells = { 20742 } },
      { label = "Hornbeam Seed", items = { 17037 }, spells = { 20747 } },
      { label = "Ironwood Seed", items = { 17038 }, spells = { 20748 } },
    } },
    { key = "wild_berries", label = "Wild Berries", items = { 17021 }, spells = { 21849 } },
    { key = "wild_thornroot", label = "Wild Thornroot", items = { 17026 }, spells = { 21850 } },
  }),

  PALADIN = class({
    { key = "symbol_of_divinity", label = "Symbol of Divinity", items = { 17033 }, low = 2, spells = { 19752 } },
    { key = "symbol_of_kings", label = "Symbol of Kings", items = { 21177 }, low = 20,
      spells = { 25898, 25782, 25894, 25895, 25890, 25899 } },
  }),

  SHAMAN = class({
    { key = "ankh", label = "Ankh", items = { 17030 }, low = 2, spells = { 20608 } },
    { key = "shiny_fish_scales", label = "Shiny Fish Scales", items = { 17057 }, spells = { 131 } },
    { key = "fish_oil", label = "Fish Oil", items = { 17058 }, spells = { 546 } },
    { key = "earth_totem", label = "Earth Totem", items = { 5175 }, low = 0, spells = { 8071 } },
    { key = "fire_totem", label = "Fire Totem", items = { 5176 }, low = 0, spells = { 3599 } },
    { key = "water_totem", label = "Water Totem", items = { 5177 }, low = 0, spells = { 5394 } },
    { key = "air_totem", label = "Air Totem", items = { 5178 }, low = 0, spells = { 8177, 8512 } },
  }),

  WARLOCK = class({
    { key = "soul_shard", label = "Soul Shard", items = { 6265 }, low = 3, spells = { 697, 6201, 693 } },
    { key = "infernal_stone", label = "Infernal Stone", items = { 5565 }, low = 1, spells = { 1122 } },
    { key = "demonic_figurine", label = "Demonic Figurine", items = { 16583 }, low = 1, spells = { 18540 } },
  }),

  HUNTER = class({
    { key = "ammo", label = "Ammo", kind = "ammo", low = 200 },
  }),

  WARRIOR = class({}),
}

-- Temporary weapon enchant ID -> display name. Only 323 is verified on Forever.
Data.enchantNames = {}
local function names(name, ids) for _, id in ipairs(ids) do Data.enchantNames[id] = name end end
names("Instant Poison", { 323, 324, 325, 623, 624, 625 })
names("Crippling Poison", { 22, 603 })
names("Deadly Poison", { 7, 8, 626, 627, 2630 })
names("Mind-numbing Poison", { 35, 23, 643 })
names("Wound Poison", { 703, 704, 705, 706 })
names("Rockbiter", { 1, 6, 29, 503, 683, 1663, 1664 })
names("Flametongue", { 3, 4, 5, 523, 1665, 1666 })
names("Frostbrand", { 2, 12, 524, 1667, 1668 })
names("Windfury", { 283, 284, 525, 1669 })

ns.Data = Data
