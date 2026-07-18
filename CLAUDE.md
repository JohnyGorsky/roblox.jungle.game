# CLAUDE.md — Roblox Jungle

**Roblox Jungle** — a Roblox game in **Luau**, synced with Roblox Studio via Roblox Studio Sync.

This file is intentionally thin. The **source of truth** for this game's architecture, Studio sync
rules, file/system map, code standards, and rules is the **`jungle-project` skill** (in
`.claude/skills/jungle-project/`). It loads automatically in the multi-root workspace — consult it
(and the shared `roblox-dev` skill for engine APIs) before doing any work here.

- **Game vision / mechanics** → [GAME.md](GAME.md)
- **Planned work** → [Planned/](Planned/) (one file per queued idea)
- **Jobs** → [Jobs/](Jobs/); scaffold with
  `python ../roblox.workspace/tools/job.py new --project jungle "Title" "Requirements"`
- **Workspace-wide ground rules** → `../roblox.workspace/GROUND-RULES.md`

> Work with the multi-root workspace open (`roblox.workspace.code-workspace`).
