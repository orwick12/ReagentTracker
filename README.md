# Reagent Tracker

A tiny addon for **World of Warcraft: Forever** that keeps a few lines of text on screen, like
Questie's quest tracker, showing:

- **Your weapon buffs.** Poison (or shaman imbue / sharpening stone) on your main hand and
  off-hand, with minutes and charges left.
- **Your reagents.** How many of the things your class needs are in your bags: Flash Powder for
  Vanish, your poisons, Soul Shards, Ankhs, runes, candles and so on.

No window, no frame. Just colored text:

```
MH Instant Poison    23m 59
OH                   NO BUFF          <- red
Flash Powder         40
Instant Poison       16
Crippling Poison     3                <- yellow
```

| Color | Means |
|---|---|
| White | All good |
| **Yellow** | Getting low: weapon buff under 10 min or under 20 charges, or fewer than 5 of an item (3 for Soul Shards, 2 for Ankhs/runes/seeds, 200 for ammo) |
| **Red** | Out: no buff on a weapon, buff under 5 min or under 5 charges, or 0 of an item |

It only lists reagents for spells **you've actually trained**. Rogue poisons show up once you
reach the level that unlocks them (Instant and Crippling at 20, Mind-numbing at 24, Deadly at 30,
Wound at 32). All ranks of a poison are counted together.

## Install

1. Go to the [**latest release**](https://github.com/orwick12/ReagentTracker/releases/latest)
   and download `ReagentTracker-x.y.z.zip`. Don't use GitHub's green "Code → Download ZIP"
   button; that's the source code, not the addon.
2. Unzip it. You get a folder named `ReagentTracker`.
3. Move that folder into your WoW Forever AddOns folder:
   - **Windows:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   - **Mac:** `/Applications/World of Warcraft/_forever_/Interface/AddOns/`

   Not sure where WoW is installed? In the Battle.net app, select WoW Forever, click the gear
   icon next to Play and choose **Show in Explorer** (Windows) or **Show in Finder** (Mac).
   Open `_forever_` → `Interface` → `AddOns`. If there's no `AddOns` folder, create it.
4. Start the game (or type `/reload` if you're already in). On the character select screen,
   click **AddOns** and make sure **Reagent Tracker** is checked.

You should end up with `...\_forever_\Interface\AddOns\ReagentTracker\ReagentTracker.toc`. If the
`.toc` is one folder deeper than that, move the inner folder up a level.

## Use

- **Move it:** left-click and drag the text.
- **Options:** right-click the text, or type `/rrt`. Click any line to stop tracking it, for
  example Instant Poison if you don't use it. Your choices are saved separately for each class.
  The menu also has **Only show problems** (hide white lines), **Lock position** and
  **Reset position**.
- **`/rrt check`:** compares each spell's in-game tooltip against the addon's reagent list and
  prints `OK` or `MISMATCH`. If something looks wrong for your class, run this and send the
  output.
- **`/rrt debug`:** lists every entry for your class and why it is or isn't showing.

## Which classes are covered

| Class | Tracks | Tested in game? |
|---|---|---|
| Rogue | Weapon poisons (MH/OH), Flash Powder, Blinding Powder, Instant / Crippling / Mind-numbing / Deadly / Wound Poison | **Yes** |
| Mage | Light Feather, Rune of Teleportation, Rune of Portals, Arcane Powder | Not yet |
| Priest | Light Feather, Holy Candle, Sacred Candle | Not yet |
| Druid | Rebirth seed (for your highest rank), Wild Berries, Wild Thornroot | Not yet |
| Paladin | Symbol of Divinity, Symbol of Kings | Not yet |
| Shaman | Weapon imbues (MH/OH), Ankh, Fish Oil, Shiny Fish Scales, the four totems | Not yet |
| Warlock | Soul Shard, Infernal Stone, Demonic Figurine | Not yet |
| Hunter | Ammo | Not yet (may not work on Forever) |
| Warrior | Weapon buffs only (off by default; turn on in the menu) | Not yet |

Weapon-buff lines start **on** for rogues and shamans and **off** for everyone else (any class can
turn them on in the menu, e.g. for sharpening stones).

The non-rogue lists come from original Classic data. If `/rrt check` reports a mismatch on your
class, please open an issue with the output.

## Known limits

- English game client only (the `/rrt check` command reads English tooltips).
- Counts only what's in your bags, not your bank.

## Development

Requires [LuaJIT](https://luajit.org/) (`brew install luajit`) and `make`.

```
make check     # syntax check + test suite (the gate)
make install   # symlink ReagentTracker/ into the local WoW Forever AddOns folder
make package   # build release/ReagentTracker-<version>.zip
```

`ReagentTracker/Data.lua` holds the per-class lists, `Logic.lua` decides what to show (fully unit
tested in `tests/`), and `Core.lua` talks to the game. The design is in `docs/superpowers/specs/`.

## License

MIT. See [LICENSE](LICENSE).
