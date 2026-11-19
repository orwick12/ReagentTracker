local _, ns = ...

-- Pure decision logic: (data, snapshot, settings) -> display lines. No WoW globals.
-- Snapshot/Settings/Line shapes are documented in docs/superpowers/plans/2026-11-19-reagent-tracker.md.

local Logic = {}
local DEFAULT_LOW = 5

local function anyKnown(spells, known)
  for _, id in ipairs(spells) do if known[id] then return true end end
  return false
end

local function highestTier(entry, known)
  for i = #entry.tiers, 1, -1 do
    if anyKnown(entry.tiers[i].spells, known) then return entry.tiers[i] end
  end
end

local function sumCounts(items, counts)
  local n = 0
  for _, id in ipairs(items) do n = n + (counts[id] or 0) end
  return n
end

function Logic.ColorForCount(count, low)
  if low == nil then low = DEFAULT_LOW end
  if count <= 0 then return "red" end
  if count < low then return "yellow" end
  return "white"
end

-- Returns status[, detail]: "active" | "level", reqLevel | "untrained" | "noweapon" | "unavailable".
function Logic.EntryStatus(entry, snapshot)
  if entry.kind == "weapon" then
    local w = snapshot.weapons and snapshot.weapons[entry.slot]
    return (w and w.equipped) and "active" or "noweapon"
  end
  if entry.kind == "ammo" then
    return snapshot.ammo ~= nil and "active" or "unavailable"
  end
  if entry.level then
    if snapshot.level >= entry.level then return "active" end
    return "level", entry.level
  end
  if entry.tiers then
    return highestTier(entry, snapshot.known) and "active" or "untrained"
  end
  return anyKnown(entry.spells, snapshot.known) and "active" or "untrained"
end

function Logic.IsEnabled(class, entry, settings, data)
  local t = settings.toggles and settings.toggles[entry.key]
  if t ~= nil then return t end
  if entry.kind == "weapon" then return data.weaponDefaultOn[class] == true end
  return true
end

function Logic.ItemLine(entry, snapshot)
  local label, count = entry.label, nil
  if entry.kind == "ammo" then
    count = snapshot.ammo
  elseif entry.tiers then
    local tier = highestTier(entry, snapshot.known)
    label, count = tier.label, sumCounts(tier.items, snapshot.counts)
  else
    count = sumCounts(entry.items, snapshot.counts)
  end
  return { key = entry.key, label = label, value = tostring(count), color = Logic.ColorForCount(count, entry.low) }
end

function Logic.BuildLines(data, snapshot, settings)
  local lines = {}
  local class = data.classes[snapshot.class]
  if not class then return lines end
  for _, entry in ipairs(class.entries) do
    if Logic.EntryStatus(entry, snapshot) == "active" and Logic.IsEnabled(snapshot.class, entry, settings, data) then
      local line
      if entry.kind == "weapon" then
        line = Logic.WeaponLine and Logic.WeaponLine(entry, snapshot.weapons[entry.slot], data)
      else
        line = Logic.ItemLine(entry, snapshot)
      end
      if line and not (settings.problemsOnly and line.color == "white") then
        lines[#lines + 1] = line
      end
    end
  end
  return lines
end

ns.Logic = Logic
