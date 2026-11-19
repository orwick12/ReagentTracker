-- THROWAWAY PROBE. Answers: which APIs exist on WoW Forever, and which return
-- secret values in / out of combat. Never compares or does math on a value
-- before checking issecretvalue(), because tainted code erroring on a secret
-- would itself hide the answer.

RRTProbeDB = RRTProbeDB or {}

local out, chat

local function add(line, toChat)
  out[#out + 1] = line
  if toChat then chat[#chat + 1] = line end
end

local isSecret = issecretvalue or function() return false end

local function describe(v, depth)
  depth = depth or 0
  local ok, secret = pcall(isSecret, v)
  if ok and secret then return "<SECRET>" end
  if type(v) == "table" then
    if depth > 1 then return "{...}" end
    local parts = {}
    for k, val in pairs(v) do
      parts[#parts + 1] = tostring(k) .. "=" .. describe(val, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  local ok2, s = pcall(tostring, v)
  return ok2 and s or "<tostring failed>"
end

local function pack(...) return { n = select("#", ...), ... } end

-- Look up a dotted global like "C_Item.GetItemCount".
local function g(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return cur
end

-- Call an API by name; record existence, errors, and every return value.
local function call(path, toChat, ...)
  local fn = g(path)
  local label = path
  if select("#", ...) > 0 then
    local a = {}
    for i = 1, select("#", ...) do a[i] = describe((select(i, ...))) end
    label = label .. "(" .. table.concat(a, ",") .. ")"
  end
  if type(fn) ~= "function" then add(label .. " -> MISSING", toChat); return end
  local res = pack(pcall(fn, ...))
  if not res[1] then add(label .. " -> ERROR " .. tostring(res[2]), toChat); return end
  local parts = {}
  for i = 2, res.n do parts[#parts + 1] = describe(res[i]) end
  add(label .. " -> " .. (#parts > 0 and table.concat(parts, " | ") or "(no returns)"), toChat)
  return res
end

local INTERESTING = { "poison", "powder", "vanish", "blind", "reagent" }
local function interesting(s)
  if type(s) ~= "string" then return false end
  local ok, low = pcall(string.lower, s)
  if not ok then return false end
  for _, w in ipairs(INTERESTING) do
    if low:find(w, 1, true) then return true end
  end
  return false
end

local function listFunctions(ns, pattern)
  local t = g(ns)
  if type(t) ~= "table" then add(ns .. " namespace MISSING", true); return end
  local names = {}
  for k in pairs(t) do
    if type(k) == "string" and k:lower():find(pattern) then names[#names + 1] = k end
  end
  table.sort(names)
  add(ns .. " matching '" .. pattern .. "': " .. (#names > 0 and table.concat(names, ", ") or "none"), true)
end

local function probeWeapons()
  add("== WEAPONS", true)
  call("GetInventoryItemLink", true, "player", 16)
  call("GetInventoryItemLink", true, "player", 17)
  call("GetWeaponEnchantInfo", true)
  call("C_Item.GetWeaponEnchantInfo", true)
  call("C_PaperDollInfo.GetTemporaryEnchantmentInfo", true)
  call("C_PaperDollInfo.GetTemporaryEnchantmentInfo", true, 16)
  call("C_PaperDollInfo.GetTemporaryEnchantmentInfo", true, 17)
  listFunctions("C_PaperDollInfo", "enchant")
  listFunctions("C_Item", "enchant")
end

local function probeAuras()
  add("== PLAYER BUFFS (poisons may be auras on this client)", true)
  local get = g("C_UnitAuras.GetAuraDataByIndex")
  if type(get) ~= "function" then add("C_UnitAuras.GetAuraDataByIndex MISSING", true); return end
  for i = 1, 40 do
    local ok, aura = pcall(get, "player", i, "HELPFUL")
    if not ok then add("aura " .. i .. " ERROR " .. tostring(aura), true); break end
    if aura == nil then break end
    local okS, secretAura = pcall(isSecret, aura)
    if okS and secretAura then add("aura " .. i .. " <SECRET TABLE>", true)
    else
      local name = aura.name
      add("aura " .. i .. ": name=" .. describe(name) .. " spellId=" .. describe(aura.spellId)
        .. " expirationTime=" .. describe(aura.expirationTime), interesting(name) or isSecret(name))
    end
  end
end

local function probeBags()
  add("== BAGS", true)
  local numSlots = g("C_Container.GetContainerNumSlots")
  local info = g("C_Container.GetContainerItemInfo")
  if type(numSlots) ~= "function" or type(info) ~= "function" then
    add("C_Container bag API MISSING", true); return
  end
  local seen = {}
  for bag = 0, 4 do
    local okN, n = pcall(numSlots, bag)
    if not okN then add("bag " .. bag .. " ERROR " .. tostring(n), true)
    elseif isSecret(n) then add("bag " .. bag .. " slot count <SECRET>", true)
    else
      for slot = 1, n do
        local ok, item = pcall(info, bag, slot)
        if not ok then add("bag " .. bag .. "/" .. slot .. " ERROR " .. tostring(item), true)
        elseif item ~= nil then
          local okId, id = pcall(function() return item.itemID end)
          if okId and id and not isSecret(id) and not seen[id] then
            seen[id] = true
            local link = item.hyperlink
            local hit = interesting(link)
            add("item " .. describe(id) .. " " .. describe(link) .. " stack=" .. describe(item.stackCount), hit)
            call("C_Item.GetItemInfoInstant", hit, id)
            call("C_Item.GetItemCount", hit, id)
          end
        end
      end
    end
  end
end

local function probeSpells()
  add("== SPELLS", true)
  local numLines = g("C_SpellBook.GetNumSpellBookSkillLines")
  local lineInfo = g("C_SpellBook.GetSpellBookSkillLineInfo")
  local itemInfo = g("C_SpellBook.GetSpellBookItemInfo")
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if type(numLines) ~= "function" or type(lineInfo) ~= "function" or type(itemInfo) ~= "function" then
    add("C_SpellBook scan API MISSING", true)
  else
    local okL, lines = pcall(numLines)
    if okL and not isSecret(lines) then
      for li = 1, lines do
        local ok, line = pcall(lineInfo, li)
        if ok and line then
          for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
            local okI, si = pcall(itemInfo, slot, bank)
            if okI and si then
              local hit = interesting(si.name)
              add("spell [" .. describe(line.name) .. "] " .. describe(si.name) .. " id=" .. describe(si.spellID)
                .. " type=" .. describe(si.itemType), hit)
              local tip = g("C_TooltipInfo.GetSpellByID")
              if type(tip) == "function" and si.spellID and not isSecret(si.spellID) then
                local okT, data = pcall(tip, si.spellID)
                if okT and type(data) == "table" and type(data.lines) == "table" then
                  for _, tl in ipairs(data.lines) do
                    if interesting(tl.leftText) or interesting(tl.rightText) then
                      add("   tooltip: " .. describe(tl.leftText) .. " / " .. describe(tl.rightText), true)
                    end
                  end
                end
              end
            end
          end
        end
      end
    else
      add("spellbook line count ERROR/SECRET " .. describe(lines), true)
    end
  end
  -- Known-spell checks on Vanish (1856, vanilla id) as a sample.
  call("IsPlayerSpell", true, 1856)
  call("IsSpellKnown", true, 1856)
  call("C_SpellBook.IsSpellKnown", true, 1856)
  call("C_SpellBook.IsSpellInSpellBook", true, 1856)
  listFunctions("C_Spell", "reagent")
  listFunctions("C_SpellBook", "known")
end

local function probe()
  out, chat = {}, {}
  add("== RRT PROBE " .. date("%Y-%m-%d %H:%M:%S"), true)
  call("GetBuildInfo", true)
  call("UnitClass", true, "player")
  call("UnitLevel", true, "player")
  call("InCombatLockdown", true)
  call("UnitAffectingCombat", true, "player")
  add("issecretvalue exists: " .. tostring(issecretvalue ~= nil), true)
  for _, step in ipairs({ probeWeapons, probeAuras, probeBags, probeSpells }) do
    local ok, err = pcall(step)
    if not ok then add("SECTION ERROR " .. tostring(err), true) end
  end
  RRTProbeDB.runs = RRTProbeDB.runs or {}
  table.insert(RRTProbeDB.runs, out)
  for _, line in ipairs(chat) do print("|cff88ccff[RRT]|r " .. line) end
  print("|cff88ccff[RRT]|r saved run #" .. #RRTProbeDB.runs .. " (" .. #out .. " lines). Type /reload later to write it to disk.")
end

SLASH_RRTPROBE1 = "/rrt"
SlashCmdList.RRTPROBE = function(msg)
  if msg == "probe" then probe()
  elseif msg == "clear" then RRTProbeDB.runs = {}; print("[RRT] cleared")
  else print("[RRT] /rrt probe  |  /rrt clear") end
end
