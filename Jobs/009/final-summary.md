# Final Summary — Job #009: Land threats + day/night cycle

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed & verified (greybox)

## What was implemented

The last P3 slice: a day/night cycle, a second threat domain (land), and time-of-day strength scaling —
so the danger flips between water and shore across the cycle (GAME.md "Threats"/"Day-night"). Also fixed
the die/spawn fall-through bug.

- **`DayNightServer`** (`ServerScriptService/World`) — cycles `Lighting.ClockTime` (full day / 240 s),
  publishes **`Phase`** ("day"/"night") + `ClockTime` Workspace attributes (replicate to clients).
- **`EnemyDefs` extended** — added the **Panther** (category "land") and
  **`strengthFor(category, phase)`**: sea ×1.5 at night / ×1.0 day; land ×1.5 day / ×0.6 night.
- **`EnemyServer` generalized** to two domains, one global tick:
  - **Sea crocs** — swim the channel, chase the boat (as before).
  - **Land panthers** — spawn ON the banks, **leashed to their anchor** (lunge up to 65 studs then slink
    back) — they ambush as you pass but can't chase across open water.
  - **Bite damage AND spawn rate scale** with `strengthFor(category, phase)` — sea threats intensify at
    night, land threats by day. (Spawn rate also still escalates with distance.)
- **Fall-through fix** (`PlayerCombat`) — the world is a regenerated river, so the default spawn was over
  the void. Players now **spawn/respawn ON the boat**, and downed players **no longer `PlatformStand`**
  (the living Humanoid floats in water / stands on land on its own, instead of ragdolling through the map).

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all four scripts.
- [x] Day/night: `Phase`=day, `ClockTime` advancing (8 → 10.3 …); cycle + `phaseFor` logic sound.
- [x] Both domains spawn: 4 crocs **in the channel** (offCenter ≈ 0), 2 panthers **ON BANK**
      (offCenter ±130 > half-width) — sea/land placement + leash confirmed.
- [x] Strength: sea day 1.0 / night 1.5; land day 1.5 / night 0.6.
- [x] **Fall-through fixed** — player spawns on the boat (Y≈17); a **downed player stays upright on the
      deck** with the revive prompt (screenshot), no void-fall.

## Files changed (roblox.jungle)

- New: `sync/ServerScriptService/World/DayNightServer.server.luau`.
- Rewritten: `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (sea + land + strength).
- Edited: `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` (Panther + `strengthFor`),
  `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (spawn-on-boat, no PlatformStand).
- New: `Jobs/009/*`.

## Notes / follow-ups

- **Not committed** (per the rule).
- Night phase (~90 s away at the current cycle length) wasn't watched to completion, but the cycle +
  strength are verified; tune `DAY_LENGTH` and add **night lighting/atmosphere polish** (fog, moon,
  searchlight) in P9 (`roblox-vfx`).
- Tunables: `DAY_LENGTH`, `strengthFor` multipliers, `MAX_SEA`/`MAX_LAND`, `LAND_LEASH`, spawn intervals.
- Land threats currently strike from the bank as you pass; they get their full purpose with **docks /
  land excursions** (P4 / `Planned/land-excursions-camps-villages.md`).
- **P3 is now feature-complete (greybox):** threats (sea+land), combat, spawn director, revive, day/night.
  Next up per roadmap: **P2 roles** or **P4 fuel/resources/docks**; art + real models at **P9**.
