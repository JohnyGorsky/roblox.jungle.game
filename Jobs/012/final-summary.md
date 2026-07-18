# Final Summary — Job #012: Big landing-site jungle zones

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Built & previewed (runtime playtest pending)

## What was implemented

Grew the excursion from a small clearing (#011) into a **big walkable jungle zone** — the "you move
into the jungle, not just hop out" vision the user drew.

- **Landing-site docks** — `RiverData.Dock` gained a **`landing`** flag (seeded; ~every other dock).
  Most docks stay quick refuel/tie stops; **only landing docks** open a jungle zone.
- **`ExcursionServer`** (rewritten) — for a landing dock:
  - **Carves a ~400-stud walkable basin** inland (`Terrain:FillBlock` grass floor + clears the steep
    mountains above locally, so they become the **ring** around the valley).
  - **Scatters ~45 greybox trees** (trunk + canopy blocks) across the land side for cover/feel.
  - **Tiered camps** — a near camp (1 guard) + a deeper camp (2 guards), each with huts + a loot crate;
    push deeper for the tougher/better one.
  - Non-landing docks build nothing extra (just the dock's refuel/tie from `DockServer`).

## Agreed parameters (with user)

Large **~400** basin; **only some** docks (special landing sites); **trees + a few camps**; all greybox
POC "to feel" the size — real trees/camps/objects come in the art pass (P9).

## Verification

- [x] `bash tools/luau-analyze.sh` clean (`RiverData`, `ExcursionServer`).
- [x] **Editor preview** (seed 2026): 1 landing zone in the 6k preview — big basin, trees, 2 camps,
      pier at the water, ringed by mountains (screenshot). Reads as a jungle valley to trek.
- [ ] **Runtime playtest pending** — walk it in Play (tie boat → trek in → loot tiered camps → haul
      back), and tune basin size / camp depth / guard counts by feel.

## Files changed

- Edited: `sync/ReplicatedStorage/River/RiverData.luau` (`Dock.landing`),
  `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (basin + trees + tiered camps).
- New: `Jobs/012/*`.

## Notes / follow-ups

- **Not committed.**
- Basin floor is a flat greybox plateau (fast); organic terrain shaping is a later/art pass concern.
- Tunables: `BASIN_SIZE`, `TREE_COUNT`, camp depths + guard counts, landing-dock frequency (`i % 2`).
- Next: dense trees on ALL shores (not just landing zones); the trailer/cargo; metal→repair + ammo
  sinks; camp/village variety + loot tables; cull far landing sites for memory.
