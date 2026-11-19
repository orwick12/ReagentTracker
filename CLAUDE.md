# Reagent Tracker — Claude Code

@AGENTS.md

## Claude-specific

- Plan mode is how "present the plan for approval before writing code" happens here.
- Write the approved plan to `tasks/todo.md` before `/clear`; resume from it afterwards.
- `/handoff` and `/handoff-save` wrap `~/.agents/handoff/README.md`. The passdown itself is
  `tasks/handoff.md`, described in AGENTS.md.

The global `~/.claude/CLAUDE.md` applies in full. Where it overlaps `AGENTS.md`, `AGENTS.md` wins.
