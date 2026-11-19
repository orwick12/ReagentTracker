# Reagent Tracker

The global working agreement applies in full — Claude Code reads it from `~/.claude/CLAUDE.md`,
Codex from `~/.codex/AGENTS.md` (the same file). This file adds only what is specific to this
project, and it is the canonical instructions for every agent. Keep it flat: no `@` import lines
(that syntax is Claude-only, and Codex reads it as literal text).

## Project facts

- What: a World of Warcraft **Forever** addon (client 1.60.1, TOC `16001`) that shows minimal
  colored text for weapon buffs (poisons) and class reagent counts, with a per-class toggle menu.
- Stack: Lua 5.1 (WoW). Tests run outside the game under LuaJIT (`brew install luajit`).
- Test: `make test` (`luajit tests/run.lua`).
- Gate: `make check` — Lua syntax check of every addon file + the full test suite. Must pass before
  any change is called done.
- Layout: `ReagentTracker/` is the addon (what ships). `Data.lua` (class tables) and `Logic.lua`
  (snapshot → display lines) are pure Lua and fully unit-tested; `Core.lua` is the only file that
  touches WoW APIs and is verified **in game only** — say so when you change it.
  `spike/RRTProbe/` is the throwaway API probe whose results back the spec's constraint table.
- Conventions: addon code must be Lua 5.1 — no `goto`, `//`, bit operators, `table.pack`, `utf8`.
  Every addon file starts `local _, ns = ...`; `Data.lua`/`Logic.lua` reference no WoW globals.
- Spec / plan: `docs/superpowers/specs/2026-11-19-reagent-tracker-design.md`,
  `docs/superpowers/plans/2026-11-19-reagent-tracker.md`.

`make help` lists every target. `make install` links the addon into the local WoW AddOns folder
and `make package` builds the release zip (addon files + LICENSE).

**`make release` is a human keystroke — agents never run it.** It ships: it runs
`scripts/release.sh`, which refuses unless on a clean `main` in sync with `origin` and with an
unused tag, then packages, commits the zip, tags `v<version>`, pushes, and publishes the GitHub
release. To ship: bump `## Version:` in `ReagentTracker/ReagentTracker.toc`, commit, push,
`make release` (optional `NOTES="..."` for release notes).

## Where things live

- `tasks/todo.md` — the working plan for the current task.
- `tasks/lessons.md` — durable corrections, read at the start of each session.
- `tasks/handoff.md` — the session passdown, newest entry on top.
- `docs/` — specs, plans, and reference material. Read on demand; never inline them here.

## Plan → build

- Write the working plan to `tasks/todo.md` with checkable items, and check in before implementing.
- Once the plan is approved, resume from `tasks/todo.md`, working items top to bottom and checking
  them off. It is written down so the build survives a context reset.
- When the work is done, add a short review section to `tasks/todo.md`.

## Memory

- When I correct your approach, append a rule to `tasks/lessons.md`: the date, what was corrected,
  and the preferred approach — phrased so it prevents the same mistake without the original
  conversation. Confirm the update in your reply.
- Review `tasks/lessons.md` at the start of each session; every rule in it applies for the session.
- Tool-private memory is a holding area, not a source of truth. Promote anything durable into this
  file, `tasks/lessons.md`, or `tasks/todo.md`, where the other tool will see it.

## Verify before done

Prove the change works: run `make check`. Don't mark a task done on untested code, and say plainly
what you did not verify (anything in `Core.lua` needs an in-game check).
