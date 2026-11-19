# Handoff log

Newest entry on top. Each entry is a snapshot so the next session starts with full context.

## 2026-11-19 14:04 — main @ 2a5f357

**Status / where we are:** Reagent Tracker v0.1.0 is built, verified in game on Brian's level 22 rogue, and public at github.com/orwick12/ReagentTracker with the installable zip on the v0.1.0 release for Brian's friend. This session added the MIT license (in the repo and, from the next release on, in the zip), uninstalled the throwaway probe addon (code kept in `spike/`), and added a human-only `make release` (`scripts/release.sh`). 36/36 tests pass (`make check`).

**Current focus:** nothing in progress; v0.1.0 is shipped.

**Next steps (high level):**
1. Verify non-rogue class data in game with `/rrt check` and fix any mismatches in `ReagentTracker/Data.lua` (see `tasks/todo.md`).
2. Ship the next version with `make release` (bump `## Version:` in the toc, commit, push first). Its commit/tag/push/publish steps have never run, so check the release page after the first use.

**Needs Brian (you):** run `/rrt check` on any non-rogue alts (or get your friend's output) and paste it; run `make release` when you want a new version out.

**Can be done autonomously:** data fixes from `/rrt check` output; drop or fix the hunter ammo entry once Forever's ammo slot is known; minor cleanup (Core.lua `ns.ClassSettings` copies `problemsOnly` into each class's saved table, redundant but harmless).

**Blockers:** none.

**Open questions:** does Forever have a hunter ammo slot? Are the rogue/shaman weapon enchant IDs other than 323 right (unknown ones show as "Buff")?

## 2026-11-19 — main @ v0.1.0 release

**Status / where we are:** Reagent Tracker v0.1.0 built, verified in game by Brian on his level 22 rogue (display, colors, OH "NO BUFF", counts, combat updates, menu toggles persist, `/rrt check`). Public repo on GitHub with `release/ReagentTracker-0.1.0.zip` committed and attached to the v0.1.0 GitHub release for a friend to install.

**Current focus:** none; v0.1.0 is done.

**Next steps (high level):**
1. Get class data verified on non-rogue characters via `/rrt check` (see `tasks/todo.md`).
2. To ship a new version: bump `## Version:` in the toc, commit + push, run `make release` (human keystroke).

**Needs Brian (you):** run `/rrt check` on any alts.

**Can be done autonomously:** data fixes from `/rrt check` output, more Logic tests.

**Blockers:** none.

**Open questions:** none. MIT license added; probe addon uninstalled (code kept in `spike/` as evidence).
