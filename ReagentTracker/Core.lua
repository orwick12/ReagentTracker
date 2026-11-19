local addonName, ns = ...

-- WoW glue only: build a snapshot from the game, hand it to Logic, draw the result.
-- No thresholds or tracking decisions live here (see Logic.lua). Verified in game only.

local Data, Logic = ns.Data, ns.Logic
local db, playerClass, ticker

local COLORS = { white = { 1, 1, 1 }, yellow = { 1, 0.82, 0 }, red = { 1, 0.2, 0.2 } }
local FONT_SIZE, LINE_HEIGHT, GAP = 12, 14, 8
local DEFAULT_POINT = { "TOPRIGHT", "TOPRIGHT", -200, -260 }
local HINT = "Reagent Tracker - right-click or /rrt"

local function say(msg) print("|cff88ccffReagent Tracker:|r " .. msg) end

local function classEntries()
  local c = Data.classes[playerClass]
  return c and c.entries or {}
end

function ns.ClassSettings()
  db.classes[playerClass] = db.classes[playerClass] or { toggles = {} }
  local s = db.classes[playerClass]
  s.problemsOnly = db.problemsOnly
  return s
end

---------------------------------------------------------------- snapshot

local isKnown = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell
local WEAPON_CLASS = 2

local function weaponState(slotID)
  local itemID = GetInventoryItemID("player", slotID)
  local equipped = false
  if itemID then
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    equipped = classID == WEAPON_CLASS
  end
  local state = { equipped = equipped }
  if equipped then
    local info = C_PaperDollInfo.GetTemporaryEnchantmentInfo(slotID)
    if info then
      state.buff = { enchantID = info.enchantID, remainingMs = info.remainingTimeMs, charges = info.chargesRemaining }
    end
  end
  return state
end

-- Ammo slot exists only on clients that define INVSLOT_AMMO. Unverified on Forever.
local function ammoCount()
  if INVSLOT_AMMO == nil then return nil end
  local ok, id = pcall(GetInventoryItemID, "player", INVSLOT_AMMO)
  if not ok then return nil end
  if not id then return 0 end
  local ok2, n = pcall(GetInventoryItemCount, "player", INVSLOT_AMMO)
  return ok2 and n or nil
end

function ns.BuildSnapshot()
  local snap = { class = playerClass, level = UnitLevel("player"), known = {}, counts = {},
    weapons = { mh = weaponState(16), oh = weaponState(17) } }
  local function addSpells(list) for _, id in ipairs(list or {}) do snap.known[id] = isKnown(id) or nil end end
  local function addItems(list) for _, id in ipairs(list or {}) do snap.counts[id] = C_Item.GetItemCount(id) end end
  for _, e in ipairs(classEntries()) do
    addSpells(e.spells); addItems(e.items)
    for _, t in ipairs(e.tiers or {}) do addSpells(t.spells); addItems(t.items) end
    if e.kind == "ammo" then snap.ammo = ammoCount() end
  end
  return snap
end

---------------------------------------------------------------- display

local frame = CreateFrame("Frame", "ReagentTrackerFrame", UIParent)
ns.frame = frame
frame:SetSize(1, 1)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

local rows = {}
local function row(i)
  if rows[i] then return rows[i] end
  local fontPath = GameFontNormal:GetFont()
  local label = frame:CreateFontString(nil, "OVERLAY")
  label:SetFont(fontPath, FONT_SIZE, "OUTLINE")
  label:SetJustifyH("LEFT")
  local value = frame:CreateFontString(nil, "OVERLAY")
  value:SetFont(fontPath, FONT_SIZE, "OUTLINE")
  value:SetJustifyH("LEFT")
  rows[i] = { label = label, value = value }
  return rows[i]
end

local function applyPoint()
  local p = db.point or DEFAULT_POINT
  frame:ClearAllPoints()
  frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function render(lines)
  if #lines == 0 and not db.locked then
    lines = { { label = HINT, value = "", color = "white" } }
  end
  local labelWidth = 0
  for i, line in ipairs(lines) do
    local r = row(i)
    r.label:SetText(line.label)
    r.value:SetText(line.value)
    local c = COLORS[line.color] or COLORS.white
    r.label:SetTextColor(c[1], c[2], c[3])
    r.value:SetTextColor(c[1], c[2], c[3])
    labelWidth = math.max(labelWidth, r.label:GetStringWidth())
  end
  local valueWidth = 0
  for i, _ in ipairs(lines) do
    local r = rows[i]
    r.label:ClearAllPoints()
    r.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * LINE_HEIGHT)
    r.value:ClearAllPoints()
    r.value:SetPoint("TOPLEFT", frame, "TOPLEFT", labelWidth + GAP, -(i - 1) * LINE_HEIGHT)
    r.label:Show(); r.value:Show()
    valueWidth = math.max(valueWidth, r.value:GetStringWidth())
  end
  for i = #lines + 1, #rows do rows[i].label:Hide(); rows[i].value:Hide() end
  frame:SetSize(math.max(labelWidth + GAP + valueWidth, 1), math.max(#lines * LINE_HEIGHT, 1))
end

function ns.Refresh()
  if not db or not playerClass then return end
  local lines = Logic.BuildLines(Data, ns.BuildSnapshot(), ns.ClassSettings())
  render(lines)
  local hasWeaponLine = false
  for _, l in ipairs(lines) do
    if l.key == "weapon_mh" or l.key == "weapon_oh" then hasWeaponLine = true end
  end
  if hasWeaponLine and not ticker then
    ticker = C_Timer.NewTicker(1, ns.Refresh)
  elseif not hasWeaponLine and ticker then
    ticker:Cancel(); ticker = nil
  end
end

---------------------------------------------------------------- menu

local GREY = "|cff888888"
local function statusSuffix(entry, snap)
  local status, detail = Logic.EntryStatus(entry, snap)
  if status == "level" then return GREY .. " (lvl " .. detail .. ")|r" end
  if status == "untrained" then return GREY .. " (not trained)|r" end
  if status == "noweapon" then return GREY .. " (no weapon)|r" end
  if status == "unavailable" then return GREY .. " (unavailable)|r" end
  return ""
end

local function menuLabel(entry)
  if entry.kind == "weapon" then return entry.label .. " weapon buff" end
  return entry.label
end

function ns.OpenMenu()
  local snap = ns.BuildSnapshot()
  local settings = ns.ClassSettings()
  MenuUtil.CreateContextMenu(frame, function(_, root)
    root:CreateTitle("Reagent Tracker (" .. playerClass:lower() .. ")")
    for _, entry in ipairs(classEntries()) do
      root:CreateCheckbox(menuLabel(entry) .. statusSuffix(entry, snap),
        function() return Logic.IsEnabled(playerClass, entry, settings, Data) end,
        function()
          settings.toggles[entry.key] = not Logic.IsEnabled(playerClass, entry, settings, Data)
          ns.Refresh()
        end)
    end
    root:CreateDivider()
    root:CreateCheckbox("Only show problems", function() return db.problemsOnly end,
      function() db.problemsOnly = not db.problemsOnly; ns.Refresh() end)
    root:CreateCheckbox("Lock position", function() return db.locked end,
      function() db.locked = not db.locked; ns.Refresh() end)
    root:CreateButton("Reset position", function() db.point = nil; applyPoint() end)
  end)
end

frame:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db.point = { p, rp, x, y }
end)
frame:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then ns.OpenMenu() end end)

---------------------------------------------------------------- slash commands

local function stripCodes(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "))
end

local function tooltipReagents(spellID)
  local data = C_TooltipInfo.GetSpellByID(spellID)
  for _, line in ipairs(data and data.lines or {}) do
    local text = line.leftText and stripCodes(line.leftText)
    local r = text and text:match("^%s*Reagents:%s*(.-)%s*$")
    if r then return r end
  end
end

local function checkData()
  local snap = ns.BuildSnapshot()
  local checked = 0
  local function checkOne(key, spells, items)
    for _, spellID in ipairs(spells) do
      if snap.known[spellID] then
        checked = checked + 1
        local tip = tooltipReagents(spellID)
        local names, unresolved = {}, false
        for _, itemID in ipairs(items) do
          local n = C_Item.GetItemNameByID(itemID)
          if n then names[#names + 1] = n else unresolved = true end
        end
        local dataNames = table.concat(names, ", ")
        local match = false
        for _, n in ipairs(names) do if tip and tip:find(n, 1, true) then match = true end end
        local spellName = C_Spell.GetSpellName(spellID) or spellID
        if match then say("OK " .. key .. " - " .. spellName .. " uses " .. tip)
        elseif not tip then say("|cffff5555NO REAGENT|r " .. key .. " - " .. spellName .. " tooltip lists no reagent (data says " .. dataNames .. ")")
        elseif unresolved and #names == 0 then say("|cffffd100UNRESOLVED|r " .. key .. " - item names not cached yet; tooltip says " .. tip)
        else say("|cffff5555MISMATCH|r " .. key .. " - " .. spellName .. ' tooltip="' .. tip .. '" data="' .. dataNames .. '"') end
      end
    end
  end
  for _, e in ipairs(classEntries()) do
    if e.spells then checkOne(e.key, e.spells, e.items) end
    for _, t in ipairs(e.tiers or {}) do checkOne(e.key, t.spells, t.items) end
  end
  say(checked .. " known spell(s) checked. Poisons/ammo are level-based and not checked here.")
end

local function debugDump()
  local snap = ns.BuildSnapshot()
  local settings = ns.ClassSettings()
  say(playerClass .. " level " .. snap.level)
  for _, e in ipairs(classEntries()) do
    local status, detail = Logic.EntryStatus(e, snap)
    local enabled = Logic.IsEnabled(playerClass, e, settings, Data)
    say(e.key .. ": " .. status .. (detail and (" " .. detail) or "") .. (enabled and "" or " [off]"))
  end
end

SLASH_REAGENTTRACKER1 = "/rrt"
SlashCmdList.REAGENTTRACKER = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "check" then checkData()
  elseif msg == "debug" then debugDump()
  else ns.OpenMenu() end
end

---------------------------------------------------------------- events

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= addonName then return end
    ReagentTrackerDB = ReagentTrackerDB or {}
    db = ReagentTrackerDB
    db.classes = db.classes or {}
    playerClass = select(2, UnitClass("player"))
    applyPoint()
    return
  end
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then return end
  ns.Refresh()
end)
