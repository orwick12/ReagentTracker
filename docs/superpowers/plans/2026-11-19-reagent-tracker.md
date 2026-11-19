# Reagent Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A WoW Forever addon that shows minimal colored text for weapon buffs and class reagent counts, with a per-class toggle menu.

**Architecture:** Pure-Lua `Data.lua` (tables) and `Logic.lua` (snapshot → display lines) are unit-tested outside the game with LuaJIT. `Core.lua` is the only file touching WoW APIs: it builds a snapshot, renders FontStrings, handles events, saved variables, menu and slash commands, and is verified by playing.

**Tech Stack:** Lua 5.1 (WoW) / LuaJIT for tests (`brew install luajit`), GNU make, WoW Forever client 1.60.1 (TOC `16001`).

**Spec:** `docs/superpowers/specs/2026-11-19-reagent-tracker-design.md`

## Global Constraints

- TOC: `## Interface: 16001`, `## SavedVariables: ReagentTrackerDB`. Addon folder name `ReagentTracker`.
- Lua 5.1 only in addon code: no `goto`, `//`, bit operators, `table.pack`, `utf8`. Tests run under LuaJIT (5.1-compatible) so violations fail.
- Every addon file starts `local _, ns = ...` and attaches to `ns` (`ns.Data`, `ns.Logic`). No globals except `ReagentTrackerDB`, `SLASH_REAGENTTRACKER1`, `SlashCmdList.REAGENTTRACKER`.
- `Data.lua` and `Logic.lua` reference **no** WoW globals.
- Slash command `/rrt`. English client only.
- Weapon thresholds: red if missing, `< 5` min, or `< 5` charges; yellow if `< 10` min or `< 20` charges; charge thresholds only when the buff has charges (`charges > 0`).
- Items: red at 0; yellow when `count < low`; default `low = 5`; `low = 0` means no yellow.
- Weapon-buff lines default on for `ROGUE` and `SHAMAN`, off for all other classes; every other entry defaults on.
- "Only show problems" defaults off.
- APIs (verified in game): `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` → `{enchantID, remainingTimeMs, chargesRemaining, hasExpirationTime}` or nothing; `C_Item.GetItemCount(itemID)`; `C_SpellBook.IsSpellKnown(id)`; `C_TooltipInfo.GetSpellByID(id)`. Do not use `C_UnitAuras` (blocked in combat).
- AddOns path: `/Applications/World of Warcraft/_forever_/Interface/AddOns` (contains spaces — quote it).

## Review Focus

1. Two-hander, shield or empty off-hand → no OH line at all (not a red "NO BUFF"). Test in Task 4.
2. Buff with no charges (sharpening stone, `charges = 0`) → judged on time only, never red for "0 charges". Test in Task 4.
3. Class with no entries (warrior) or a class not in data at all → `BuildLines` returns `{}` without error. Test in Task 3.
4. Unknown enchant ID → label falls back to `"Buff"`. Test in Task 4.
5. Exact threshold boundaries (5:00 left is yellow, 4:59 red; count == low is white) — off-by-one is the likeliest bug. Tests in Tasks 3 and 4.

---

## Shared shapes (defined in Tasks 2–3, used everywhere)

```lua
-- Entry (Data.lua)
{ key = "flash_powder", label = "Flash Powder",
  items = {5140},            -- counts summed across these item IDs
  spells = {1856, 1857},     -- shown if ANY is known   (or)
  level = 20,                -- shown if player level >= level
  low = 5,                   -- optional, default 5; 0 = no yellow
  tiers = { {label=, items={}, spells={}}, ... },  -- optional; highest known tier wins (druid seeds)
  kind = "item" | "weapon" | "ammo",              -- default "item"
  slot = "mh" | "oh" }                            -- weapon only

-- Snapshot (built by Core.lua, hand-built in tests)
{ class = "ROGUE", level = 22,
  known = { [1856] = true },
  counts = { [5140] = 40 },
  ammo = 0 | nil,
  weapons = { mh = { equipped = true, buff = { enchantID = 323, remainingMs = 1417700, charges = 59 } | nil },
              oh = { equipped = false } } }

-- Settings (per class, from ReagentTrackerDB)
{ toggles = { [key] = true|false },   -- nil = use default
  problemsOnly = false }

-- Line (Logic output)
{ key = "flash_powder", label = "Flash Powder", value = "40", color = "white"|"yellow"|"red" }
```

---

### Task 1: Project scaffold and test harness

**Files:**
- Create: `AGENTS.md`, `CLAUDE.md`, `README.md`, `.gitignore`, `Makefile`, `tasks/handoff.md`, `tasks/todo.md`, `tasks/lessons.md`, `docs/README.md`
- Create: `tests/run.lua`, `tests/test_harness.lua`
- Create: `ReagentTracker/ReagentTracker.toc`

The `new-project` scaffold script can't be used (directory isn't empty; no Lua toolchain). Mirror its layout by hand, adapting `~/.claude/skills/new-project/templates/{AGENTS.md,CLAUDE.md,tasks/*,docs/README.md}`. AGENTS.md must name: `make check` as the gate, LuaJIT for tests, the Lua 5.1 rule, that `Core.lua` is verified in game only, and that `make install` writes into the WoW folder (a human keystroke). `CLAUDE.md` = `@AGENTS.md` + the Claude-only section from the template. `.gitignore`: `.DS_Store`, `.env`, `.claude/settings.local.json`.

**Interfaces:**
- Produces: `tests/run.lua` — loads addon files into a shared `ns` with `loadfile(path)("ReagentTracker", ns)`, defines globals `test(name, fn)`, `eq(actual, expected, msg)` (deep-compares tables), `ok(cond, msg)`, then runs every `tests/test_*.lua`, prints `PASS`/`FAIL name: message` per test and a summary, exits 1 on any failure. Exposes `load_addon(...)` returning a fresh `ns` with the named files loaded in order.
- Makefile targets: `help` (default), `test` (`luajit tests/run.lua`), `lint` (`luajit -bl` each `ReagentTracker/*.lua` to `/dev/null` — syntax check), `check` (lint + test), `install` (`ln -sfn "$(CURDIR)/ReagentTracker" "$(WOW_ADDONS)/ReagentTracker"`, `WOW_ADDONS ?=` the AddOns path), `uninstall` (remove that link only if it is a symlink).

- [ ] **Step 1:** `brew install luajit`; `luajit -v` prints a version.
- [ ] **Step 2:** `git init -b main`.
- [ ] **Step 3: Write `tests/test_harness.lua`** — `test("eq deep-compares tables", function() eq({a={1,2}}, {a={1,2}}) end)` and `test("harness reports failure", ...)` that asserts `pcall(eq, 1, 2)` returns false.
- [ ] **Step 4:** Write `tests/run.lua`, Makefile, toc (`## Interface: 16001`, `## Title: Reagent Tracker`, `## SavedVariables: ReagentTrackerDB`, files `Data.lua`, `Logic.lua`, `Core.lua`), and empty `Data.lua`/`Logic.lua`/`Core.lua` each containing only `local _, ns = ...`.
- [ ] **Step 5:** `make check` → lint passes, `2 passed, 0 failed`. Temporarily change an assertion to fail and confirm `make check` exits non-zero; revert.
- [ ] **Step 6: Commit** everything including `docs/`, `spike/`:
  `git add -A && git commit -m "chore: scaffold reagent tracker, test harness, design + spike"`

### Task 2: Class data

**Files:**
- Modify: `ReagentTracker/Data.lua`
- Test: `tests/test_data.lua`

**Interfaces:**
- Produces: `ns.Data.classes[CLASS] = { entries = { Entry, ... } }` for `ROGUE, MAGE, PRIEST, DRUID, PALADIN, SHAMAN, WARLOCK, HUNTER, WARRIOR`; `ns.Data.enchantNames[enchantID] = "Instant Poison"`; `ns.Data.weaponDefaultOn = { ROGUE = true, SHAMAN = true }`.
- Every class's entries begin with the two weapon entries `{key="weapon_mh", kind="weapon", slot="mh", label="MH"}` and `{key="weapon_oh", kind="weapon", slot="oh", label="OH"}`.

Entry contents: copy the spec's "Data (v1 lists)" section exactly (IDs, levels, `low` values). Rogue poison families are level entries (`level = 20` etc.) with all rank item IDs in `items`. Druid seeds are one entry `key="rebirth_seed"` with `tiers` in rank order. Shaman totems are four entries with `low = 0`. Hunter is one `kind="ammo"` entry `key="ammo"`, `low = 200`.

`enchantNames` (only 323 is verified; the rest best-effort): Instant Poison 323, 324, 325, 623, 624, 625; Crippling Poison 22, 603; Deadly Poison 7, 8, 626, 627, 2630; Mind-numbing Poison 35, 23, 643; Wound Poison 703, 704, 705, 706; Rockbiter 1, 6, 29, 503, 683, 1663, 1664; Flametongue 3, 4, 5, 523, 1665, 1666; Frostbrand 2, 12, 524, 1667, 1668; Windfury 283, 284, 525, 1669.

- [ ] **Step 1: Write `tests/test_data.lua`:**
  - `"every entry has key, label, and a way to unlock"` — for each class/entry: `key` and `label` are strings; non-weapon entries have exactly one of `spells`, `level`, `tiers`, or `kind=="ammo"`.
  - `"keys are unique within a class"`.
  - `"item entries have at least one item id"` (non-weapon, non-ammo, non-tier).
  - `"verified rogue data"` — rogue entry `flash_powder` has `items={5140}` and contains spell 1856; `instant_poison` has `level=20` and contains item 6947; `crippling_poison` has `level=20` and contains 3775; `enchantNames[323] == "Instant Poison"`.
  - `"warrior has only weapon entries"`; `"all nine classes present"`.
- [ ] **Step 2:** `make test` → these fail (`ns.Data` is nil). Show output.
- [ ] **Step 3: Commit tests:** `git commit -m "test: class data shape"`.
- [ ] **Step 4:** Fill `Data.lua`.
- [ ] **Step 5:** `make check` → all pass.
- [ ] **Step 6: Commit:** `git commit -m "feat: per-class reagent data"`.

### Task 3: Entry resolution and item lines

**Files:**
- Modify: `ReagentTracker/Logic.lua`
- Test: `tests/test_logic_items.lua`

**Interfaces:**
- Consumes: `ns.Data` shapes from Task 2.
- Produces:
  - `ns.Logic.EntryStatus(entry, snapshot) -> status, detail` — `"active"`; `"level", reqLevel`; or `"untrained"`. Weapon entries: `"active"` if that slot is equipped, else `"noweapon"`. Ammo: always `"active"` when `snapshot.ammo ~= nil`, else `"unavailable"`.
  - `ns.Logic.IsEnabled(class, entry, settings, data) -> bool` — `settings.toggles[key]` if not nil, else weapon entries → `data.weaponDefaultOn[class] == true`, others → `true`.
  - `ns.Logic.ItemLine(entry, snapshot) -> Line` — for tiers, picks the highest tier with a known spell and uses its label/items. For `kind="ammo"`, count is `snapshot.ammo`.
  - `ns.Logic.ColorForCount(count, low) -> color` — `low` defaults to 5.
  - `ns.Logic.BuildLines(data, snapshot, settings) -> {Line...}` — class entries in data order; only active + enabled; dispatches weapon entries to `WeaponLine` (Task 4; until then skip them); drops white lines when `settings.problemsOnly`. Unknown class → `{}`.

- [ ] **Step 1: Write `tests/test_logic_items.lua`** (snapshots hand-built per the shared shapes):
  - `"count colors"` — `ColorForCount(0,5)=="red"`, `(4,5)=="yellow"`, `(5,5)=="white"`, `(0,0)=="red"`, `(1,0)=="white"`, `(3,nil)=="yellow"`.
  - `"untrained spell entry hidden"` — rogue level 22, `known={}` → no `flash_powder` line.
  - `"known spell shows summed count"` — `known={[1856]=true}`, `counts={[5140]=40}` → line `{key="flash_powder", label="Flash Powder", value="40", color="white"}`.
  - `"poison ranks summed and level gated"` — level 22, counts `{[6947]=10,[6949]=6,[2892]=5}` → `instant_poison` value `"16"`; no `deadly_poison` line (level 30); `EntryStatus(deadly, snap)` returns `"level", 30`.
  - `"missing reagent is red zero"` — known Vanish, no counts → value `"0"`, color `"red"`.
  - `"druid highest tier wins"` — known 20484 and 20739, counts `{[17035]=1}` → label `"Stranglethorn Seed"`, value `"1"`, color `"yellow"` (low 2).
  - `"hunter ammo"` — `ammo=150` → `{key="ammo", value="150", color="yellow"}`; `ammo=nil` → no ammo line.
  - `"toggle off hides line"`, `"toggle on overrides weapon default"` (via `IsEnabled`).
  - `"problemsOnly drops white lines"`.
  - `"warrior and unknown class produce no lines"` — `class="WARRIOR"`, no weapons equipped → `{}`; `class="EVOKER"` → `{}`.
- [ ] **Step 2:** `make test` → new tests fail for missing functions. Show output.
- [ ] **Step 3: Commit tests.**
- [ ] **Step 4:** Implement in `Logic.lua`.
- [ ] **Step 5:** `make check` → all pass.
- [ ] **Step 6: Commit** `feat: entry resolution and item lines`.

### Task 4: Weapon buff lines

**Files:**
- Modify: `ReagentTracker/Logic.lua`
- Test: `tests/test_logic_weapons.lua`

**Interfaces:**
- Produces:
  - `ns.Logic.FormatTime(ms) -> string` — `>= 60000` → `floor(ms/60000).."m"`, else `floor(ms/1000).."s"`.
  - `ns.Logic.WeaponLine(entry, weapon, data) -> Line|nil` — nil if `not weapon.equipped`. No buff → `label = entry.label`, `value = "NO BUFF"`, red. With buff → `label = entry.label.." "..(data.enchantNames[id] or "Buff")`, `value = FormatTime(ms)` plus `" "..charges` when `charges > 0`, color per Global Constraints thresholds (worst of time and charge colors).
  - `BuildLines` now includes weapon lines.

- [ ] **Step 1: Write `tests/test_logic_weapons.lua`:**
  - `"format time"` — `FormatTime(1417700)=="23m"`, `(59999)=="59s"`, `(60000)=="1m"`.
  - `"healthy poison"` — enchant 323, 1417700 ms, 59 charges → `{key="weapon_mh", label="MH Instant Poison", value="23m 59", color="white"}`.
  - `"missing buff red"` — `{equipped=true}` → value `"NO BUFF"`, red.
  - `"no off-hand weapon, no line"` — `{equipped=false}` → nil; rogue BuildLines has no `weapon_oh`.
  - `"time boundaries"` — 300000 ms → yellow; 299999 → red; 600000 → white; 599999 → yellow (charges 59).
  - `"charge boundaries"` — 20 charges white, 19 yellow, 5 yellow, 4 red (time 30m).
  - `"no-charge buff judged on time only"` — charges 0, 30m → white, value `"30m"`.
  - `"unknown enchant labelled Buff"` — enchant 99999 → label `"MH Buff"`.
  - `"weapon lines default off for mage, on for shaman"` — via BuildLines with equipped MH and no toggles.
- [ ] **Step 2:** `make test` → fail. Show output.
- [ ] **Step 3: Commit tests.**
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** `make check` → all pass.
- [ ] **Step 6: Commit** `feat: weapon buff lines`.

### Task 5: In-game display (Core.lua)

No unit tests — WoW glue only (spec: "Core.lua is checked by playing"). Keep it thin: no thresholds or decisions here.

**Files:**
- Modify: `ReagentTracker/Core.lua`

**Interfaces:**
- Consumes: `ns.Data`, `ns.Logic.BuildLines`.
- Produces: `ns.BuildSnapshot() -> Snapshot`; `ns.Refresh()`; `ns.ClassSettings() -> Settings` (creates `ReagentTrackerDB.classes[CLASS] = {toggles={}}` on first use; `problemsOnly`, `locked`, `point` live at the DB root); `ns.frame` (anchor).

Snapshot from APIs: `UnitClass("player")` second return, `UnitLevel`, `C_SpellBook.IsSpellKnown` for every spell ID in the class's entries (incl. tiers), `C_Item.GetItemCount` for every item ID, weapons via `GetInventoryItemID("player", 16/17)` + `C_Item.GetItemInfoInstant` classID `== 2` for `equipped`, buff from `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` mapped to `{enchantID, remainingMs = remainingTimeMs, charges = chargesRemaining}`. Ammo: `GetInventoryItemCount("player", 0)` inside `pcall`; nil on error or if returns nil.

Rendering: anchor frame, no backdrop; per line two FontStrings (label left, value at a fixed x offset) using `GameFontNormal` with `"OUTLINE"`; colors white `1,1,1`, yellow `1,0.82,0`, red `1,0.2,0.2`. Reuse FontStrings; hide extras. Default point: `TOPRIGHT`, `UIParent`, `-200, -260`. Drag with left mouse when `not locked`; save `point` on drag stop.

Events: `ADDON_LOADED` (init DB), `PLAYER_ENTERING_WORLD`, `BAG_UPDATE_DELAYED`, `UNIT_INVENTORY_CHANGED` (unit `"player"`), `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_LEVEL_UP`, `SPELLS_CHANGED` → `ns.Refresh()`. `C_Timer.NewTicker(1, ns.Refresh)` running only while a weapon line is shown.

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** `make check` → lint + tests pass.
- [ ] **Step 3:** `make install`. Ask the user to `/reload` and confirm: MH line shows poison/time/charges; OH shows red NO BUFF when un-poisoned; Flash Powder / Instant / Crippling counts match bags; counts update when buying/selling; timer counts down; values still update mid-combat; no Lua errors; text drags and stays after `/reload`.
- [ ] **Step 4: Commit** `feat: in-game display`.

### Task 6: Menu and slash commands

**Files:**
- Modify: `ReagentTracker/Core.lua`

**Interfaces:**
- Consumes: `ns.Logic.EntryStatus`, `ns.Logic.IsEnabled`, `ns.ClassSettings`, `ns.Refresh`.

Menu (`MenuUtil.CreateContextMenu(ns.frame, generator)` — verify it exists first with `/run print(MenuUtil and MenuUtil.CreateContextMenu)`; if nil, build a minimal frame of `UICheckButtonTemplate` checkboxes instead and note it in AGENTS.md): one checkbox per class entry, labelled with `entry.label` plus a grey suffix ` (lvl N)` / ` (not trained)` / ` (no weapon)` from `EntryStatus`; checking writes `toggles[key]`; then "Only show problems", "Lock position", "Reset position". Opened by right-click on the anchor and by bare `/rrt`. Right-click must work even when the text is empty: if no lines are shown, keep a one-line hint `"Reagent Tracker – /rrt"` visible only while unlocked.

Slash: `/rrt` (menu), `/rrt debug` (print each class entry: key, status, enabled, count), `/rrt check` (for each entry whose spells are known: read `C_TooltipInfo.GetSpellByID`, find the line starting `"Reagents:"`, strip `"|n"`, compare to `C_Item.GetItemNameByID` of the entry's items; print `OK`, `MISMATCH tooltip="…" data="…"`, or `UNRESOLVED` when the item name isn't cached).

- [ ] **Step 1:** Implement.
- [ ] **Step 2:** `make check` passes.
- [ ] **Step 3:** In game: toggle Instant Poison off → line disappears and stays off after `/reload`; log a non-rogue alt (if available) and confirm toggles are separate; `/rrt check` on rogue prints `OK` for Vanish; `/rrt debug` lists entries.
- [ ] **Step 4: Commit** `feat: toggle menu and slash commands`.

### Task 7: Clean up and handoff

- [ ] **Step 1:** Ask the user before removing the probe link `"$WOW_ADDONS/RRTProbe"` (symlink only) and `spike/`'s saved variables. Keep `spike/` in git as the evidence for the spec's constraint table.
- [ ] **Step 2:** Update `tasks/todo.md` with: verify non-rogue data via `/rrt check` per class; ammo slot unverified; enchant IDs other than 323 unverified.
- [ ] **Step 3:** `make check`; write `tasks/handoff.md` entry; commit `docs: handoff`.
