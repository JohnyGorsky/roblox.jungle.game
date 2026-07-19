# Final Summary — Job #053: Camp rework — clear path + escalating non-respawning rosters

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#5 of 6**
(`Planned/river-journey-overhaul.md`). Game place. Greybox. (User feedback #3.)

## What
Landing-site excursions now read as intended: you disembark onto a **clear, tree-free path** that leads to the
camps, and camp guards are a **predefined, non-respawning** roster that **escalates at each successive landing**.

## Implementation (`sync/ServerScriptService/Excursion/ExcursionServer.server.luau`)
- **Clear walking lane**: computed the shore→deep-camp segment first, then when scattering the 45 basin trees,
  **skip any tree within `PATH_HALF` (18 studs) of that segment** (`distToSeg` helper). Also lay a visible dirt
  **`CampPath`** strip along the lane.
- **Escalating rosters**: `tier = ceil(dockIndex/2)` (the landing's ordinal downriver) →
  `nearGuards = tier`, `deepGuards = tier + 1`, capped at `MAX_GUARDS` (6). Each successive landing (and the
  deeper camp within a site) has more guards.
- **Non-respawning** (unchanged): guards are spawned once at build and never respawn on death — just more of
  them at later landings.

## Verified (live in Studio — untied boat parked at the first landing, made invincible for inspection)
- [x] Analyzer-clean.
- [x] First landing (z=2200, tier 1) built with **3 guards** (near 1 + deep 2); escalation preview
      L1=1/2, L3=2/3, L5=3/4.
- [x] **Clear lane proven**: of 41 placed trees, **0 lie within 18 studs of the path** (nearest 19.1 studs);
      `CampPath` dirt strip (~295 studs, shore→deep camp) present; 5 loot crates.
- [x] Two camps at increasing depth (near ~120, deep ~300 studs inland).

## Notes / follow-ups
- **Not committed.**
- To inspect I had to **untie properly** (destroy the Moor **and** the rope tether — the rope alone kept the
  boat pinned to the winch) then hold it near the landing. Noted for future test harnesses.
- Screenshots were hampered by the day/night cycle + depth-of-field over the wide basin, so the clear lane was
  confirmed **quantitatively** (0 trees on the lane) rather than by picture.
- Loot/resource tiers are unchanged (near gasoline; deep metal+ammo+weapon/ammo crates); could also scale with
  tier later. Next: **#6 pacing & optional stops** (the last overhaul item).
