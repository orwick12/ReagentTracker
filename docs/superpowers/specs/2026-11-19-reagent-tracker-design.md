# Reagent Tracker — design

Date: 2026-11-19. Status: draft, awaiting approval.

## Intent

A WoW Forever addon that shows, as a few lines of plain on-screen text (Questie-style, no window
or backdrop), whether you're carrying what your class needs and whether your weapon buffs are up.
It's meant to be glanced at, not managed: colors carry the warning (red = out/missing,
yellow = getting low). A small click menu turns individual lines on and off, per class.

The user plays a level 22 rogue today; rogue is the class that matters most and the only one
verified in game. Every other class ships with a best-effort list.

## Goals

- Show weapon buffs (poisons, shaman imbues, sharpening stones/oils) for main hand and off-hand:
  name, minutes left, charges left. Red when missing or nearly gone, yellow when getting low.
- Show bag counts for the reagents your *trained spells* use (e.g. Vanish → Flash Powder) and,
  for rogues, the poisons your *level* unlocks. Red at 0, yellow below a "low" number.
- Updates live, including in combat.
- A menu (`/rrt`, or right-click the text) with one checkbox per line, remembered per class.
- Movable; position saved.

## Non-goals

- No window, frame art, icons, or bars. Text only.
- No bank counts, no shopping list, no vendor integration, no auto-buying.
- No buff tracking (player auras are blocked in combat on this client, and aren't the job).
- No localization: English client only.
- No "you're carrying a lower poison rank than you could" warning (possible later).

## Anti-goals (fails even if it works)

- Noisy: flashing, sounds, chat spam, or so many lines it covers the screen.
- Nagging about spells you haven't trained.
- Causing taint / "addon blocked" errors in combat.

## Constraints (verified in game 2026-11-19 with a throwaway probe, `spike/RRTProbe`)

Client: WoW Forever 1.60.1 build 70959, TOC interface `16001`, built on the modern (Midnight)
client with Midnight's "secret values" addon restrictions. Addons folder:
`/Applications/World of Warcraft/_forever_/Interface/AddOns`. Questie ships a `_Forever.toc`
there, a working reference.

| Need | API | Result (out of combat / in combat) |
|---|---|---|
| Weapon buff | `C_PaperDollInfo.GetTemporaryEnchantmentInfo(16 or 17)` → `{enchantID, remainingTimeMs, chargesRemaining, hasExpirationTime}`; returns nothing when no buff. `GetWeaponEnchantInfo()` also works. | readable / readable, not secret |
| Bag count | `C_Item.GetItemCount(itemID)` (sums stacks: 2×20 Flash Powder → 40) | readable / readable |
| Trained spell | `C_SpellBook.IsSpellKnown(id)`, `IsPlayerSpell(id)` (Vanish 1856 → true) | readable / readable |
| Spell's reagent | `C_TooltipInfo.GetSpellByID(id)` lines include `"Reagents: \|nFlash Powder"` | readable / readable |
| Player auras | `C_UnitAuras.GetAuraDataByIndex` | readable / **blocked** (error) |

Item and spell IDs match original Classic (Vanish 1856, Flash Powder 5140, Instant Poison 6947,
Crippling Poison 3775). Enchant ID 323 = Instant Poison. Poisons are bag items applied as
temporary weapon enchants and do **not** appear as spells, so poison tracking is by level.

## Approaches

- **A. Hand-written per-class data (chosen by user).** Tables of spell IDs → reagent item IDs,
  plus rogue poisons by level. Predictable; can always show a red 0 because it knows the item ID.
  Cost: writing the lists once.
- **B. Auto-discover from spell tooltips.** No lists, every class works immediately — but when
  you have 0 of an item the game often can't resolve the name to an ID, so the most important
  case (you're out) goes blank; English-only; can't cover poisons. Rejected.
- A hybrid was dropped: both sets of weaknesses to save ~10 lines per class.

The tooltip reading from B is kept for one job only: a `/rrt check` command that compares each
known spell's tooltip reagent against the data list and prints mismatches. That's how the
untested classes get verified cheaply.

## What the user decided

- Approach A; Claude writes the list for every class.
- Layout, colors and default thresholds as proposed (below).
- Off-hand with no buff should go red (the motivating case).

## Behaviour

### Display

Plain FontStrings on an invisible anchor frame, outlined font, left-aligned, one line per item:

```
MH  Instant Poison   23m  59
OH  NO BUFF                        (red)
Flash Powder       40
Instant Poison     16
Crippling Poison   10              (yellow if below low)
```

- Line text color: white normally, yellow when low, red when out/missing.
- Weapon line shows time as `Nm` (or `Ns` under a minute) and charges if the buff has them.
- A weapon line appears only if a weapon is in that slot (`GetInventoryItemID`, item classID 2).
  No off-hand weapon (shield, held item, two-hander) → no OH line.
- Weapon buff name comes from an enchant-ID → name table in the data file; unknown IDs show as
  "Buff". (Builder: fill rogue poison enchant IDs from wowhead classic; 323 confirmed.)
- Rogue poison lines sum all ranks of a family (Instant I–VI count as "Instant Poison").
- Menu option "Only show problems" (default **off**, since the user wants counts as a quick
  reference): when on, white lines are hidden.

### Thresholds (defaults)

- Weapon buff: **red** if missing, < 5 min, or < 5 charges; **yellow** if < 10 min or < 20
  charges. Charge thresholds apply only when the buff has charges.
- Items: **red** at 0; **yellow** below the item's `low` value (default 5; per-item overrides in
  the data, e.g. Soul Shard 3, ammo 200, totems/Ankh have no yellow).
- Thresholds are data, not menu options, in v1 (keeps the menu a plain checklist). Builder may
  expose them later if asked.

### What gets tracked

An entry shows when: the player's class matches, AND (any of its spell IDs is known, OR the
player level ≥ its level for level-gated entries), AND the user hasn't toggled it off.

Weapon-buff lines default **on** for rogue and shaman, **off** (but available in the menu) for
everyone else.

### Menu

`/rrt` or right-clicking the text opens a context menu (`MenuUtil.CreateContextMenu`, modern
API — **unverified on Forever**, fall back to a tiny custom checkbox frame if missing):

- One checkbox per entry for your class (all entries listed, even ones not yet unlocked, greyed
  out with "(lvl 30)" / "(not trained)" so you can pre-toggle).
- Lock / unlock position (unlocked = drag with left mouse).
- Only show problems.
- Reset position.

Other commands: `/rrt check` (data self-check), `/rrt debug` (print which entries matched and why).

### Updates

Events: `PLAYER_ENTERING_WORLD`, `BAG_UPDATE_DELAYED`, `UNIT_INVENTORY_CHANGED` (player),
`PLAYER_EQUIPMENT_CHANGED`, `PLAYER_LEVEL_UP`, `SPELLS_CHANGED`, plus a 1-second ticker for
weapon timers (only while a weapon line is shown). Cheap: a handful of API calls per tick.

### Saved data

`ReagentTrackerDB` (account-wide): `point` (position), `locked`, `problemsOnly`,
`classes[CLASS].toggles[entryKey] = true|false` (nil = default; needed because weapon lines
default off for some classes). Toggling is per class because it's keyed by class.

## Data (v1 lists)

Verified in game: rogue Vanish/Flash Powder, Instant, Crippling. Everything else is from
original Classic knowledge and **unverified on Forever** — `/rrt check` exists to catch errors.
Spell lists include every rank so any trained rank counts.

**Rogue**
- Flash Powder 5140 — Vanish 1856, 1857
- Blinding Powder 5530 — Blind 2094
- Poisons by level (item IDs per rank, summed): Instant 20 (6947, 6949, 6950, 8926, 8927, 8928);
  Crippling 20 (3775, 3776); Mind-numbing 24 (5237, 6951, 9186); Deadly 30 (2892, 2893, 8984,
  8985, 20844); Wound 32 (10918, 10920, 10921, 10922)

**Mage**
- Light Feather 17056 — Slow Fall 130
- Rune of Teleportation 17031 — Teleport: Stormwind 3561, Ironforge 3562, Darnassus 3565,
  Orgrimmar 3567, Undercity 3563, Thunder Bluff 3566 (low 2)
- Rune of Portals 17032 — Portal: Stormwind 10059, Ironforge 11416, Darnassus 11419,
  Orgrimmar 11417, Undercity 11418, Thunder Bluff 11420 (low 2)
- Arcane Powder 17020 — Arcane Brilliance 23028 (low 10)

**Priest**
- Light Feather 17056 — Levitate 1706
- Holy Candle 17028 — Prayer of Fortitude r1 21562
- Sacred Candle 17029 — Prayer of Fortitude r2 21564, Prayer of Spirit 27681,
  Prayer of Shadow Protection 27683

**Druid**
- Rebirth seeds by rank (show the seed for your highest known rank): Maple 17034 (20484),
  Stranglethorn 17035 (20739), Ashwood 17036 (20742), Hornbeam 17037 (20747),
  Ironwood 17038 (20748) (low 2)
- Wild Berries 17021 — Gift of the Wild r1 21849
- Wild Thornroot 17026 — Gift of the Wild r2 21850

**Paladin**
- Symbol of Divinity 17033 — Divine Intervention 19752 (low 2)
- Symbol of Kings 21177 — Greater Blessings: Kings 25898, Might 25782, Wisdom 25894,
  Salvation 25895, Light 25890, Sanctuary 25899 (low 20)

**Shaman**
- Ankh 17030 — Reincarnation 20608 (low 2)
- Shiny Fish Scales 17057 — Water Breathing 131
- Fish Oil 17058 — Water Walking 546
- Totems (tool, need 1, red if missing, no yellow): Earth Totem 5175 — Stoneskin Totem 8071;
  Fire Totem 5176 — Searing Totem 3599; Water Totem 5177 — Healing Stream Totem 5394;
  Air Totem 5178 — Grounding Totem 8177, Windfury Totem 8512

**Warlock**
- Soul Shard 6265 — Summon Voidwalker 697, Create Healthstone 6201, Soulstone 693 (low 3)
- Infernal Stone 5565 — Inferno 1122 (low 1)
- Demonic Figurine 16583 — Ritual of Doom 18540 (low 1)

**Hunter**
- Ammo: count of equipped ammo (`GetInventoryItemCount("player", 0)`, **unverified on
  Forever** — the modern client may have no ammo slot; if so, drop this entry) (low 200)

**Warrior**: none. Weapon-buff lines (stones) available in the menu, default off.

## Code layout (builder may adjust)

```
ReagentTracker/
  ReagentTracker.toc     ## Interface: 16001, SavedVariables: ReagentTrackerDB
  Data.lua               class tables, enchant-name table (pure data)
  Logic.lua              pure functions: (snapshot, data, settings) -> list of {text, color}
  Core.lua               WoW glue: events, snapshot from APIs, rendering, menu, slash cmds
tests/
  test_logic.lua         plain Lua tests of Logic.lua against hand-built snapshots
Makefile                 make test / make check / make install (symlink into AddOns)
```

`Logic.lua` takes no WoW globals — a snapshot table `{class, level, known = {[spellID]=true},
counts = {[itemID]=n}, weapons = {mh = {...}|nil, oh = ...}}` in, display lines out — so
thresholds, colors, level gating, rank summing and toggles are unit-tested with plain Lua
(`brew install lua`). `Core.lua` is checked by playing.

## Left to the builder

- Exact font, size, line spacing, default position (suggest top-right under the minimap, near
  where Questie sits).
- Enchant-ID → name table contents.
- Test runner shape (plain asserts are fine; no framework required).
- Project scaffolding per the user's global layout (git init, AGENTS.md, CLAUDE.md, Makefile,
  tasks/).

## Known risks

- Non-rogue data is unverified on Forever (content differs from vanilla in places).
- `MenuUtil.CreateContextMenu` and the ammo slot are unverified.
- Blizzard can change secret-value rules in a patch; weapon/bag/spell reads could become secret
  in combat later.
