# Final Summary — Job #033: Enemy roster + tougher spawn director

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Deepens the core run. Game-only.

## What was built
Three new data-driven enemy types (reusing the existing bite/leash AI) + a director that spawns the right
mix by distance and time of day and escalates its caps.

### New enemies (`EnemyDefs`)
- **Piranha** — sea, fast, fragile (15 HP), tiny frequent bites → swarms.
- **RiverHippo** — sea, slow, tanky (120 HP), big bite → deep-river mini-threat.
- **Boar** — land, fast pack charger.

### Director (`EnemyServer`)
- **Weighted pools** per category; weights lerp from "near" → "far" with distance (e.g. hippo only appears
  deep; boars/piranha grow more common downriver).
- **Caps scale with distance** (sea 4→9, land 2→5) **+ a night surge** (+2 sea) — replaces the old fixed
  per-type caps; cap is now per-category total.
- Existing time-of-day damage/interval scaling (sea peaks night, land by day) unchanged.

## Verified (live in Studio)
- [x] Analyzer-clean (both files).
- [x] Parked deep (~z11000, day) + RunStarted → spawned **Piranha×6, RiverHippo×1, Panther×3, Boar×1**
      (sea 7 / land 4) — variety, the deep-only hippo, and scaled caps all confirmed.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Greybox bodies (design pass later). Ranged/tribal enemies (projectiles) deferred — all current types reuse
  the melee-bite AI.
- Next in the "deepen the run" set: **#034 role-station bonuses**, **#035 zones + day/night stakes**.
