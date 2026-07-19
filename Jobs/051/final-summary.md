# Final Summary — Job #051: Off-path dense & dangerous (bank forest + bank threats)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#4 of 6**
(`Planned/river-journey-overhaul.md`). Game place. Greybox.

## What
Makes the river the *safe corridor* and the banks *hostile jungle*: a thick treeline walls the channel and
land ambushers are more numerous/frequent, so hugging a bank or going ashore off a landing is punished.
(User feedback #2: off-path = dense trees + frequent spawns.)

## Implementation
- **`sync/ServerScriptService/World/FoliageServer.server.luau`**:
  - Density up (`PER_BANK` 8→16, `BAND` 130→150) → a thick jungle wall.
  - **Inland-biased** placement (`inland = 4 + (BAND-4) * rng^0.6`) → lighter at the shore, dense back-forest.
  - **Fork-aware**: trees plant beyond the *outermost branch edge* (`branchesAt`) — never in a fork channel or
    on an island.
  - **Clearing** (`DOCK_CLEAR` 30) around landing docks so you can still disembark.
- **`sync/ServerScriptService/Enemies/EnemyServer.server.luau`**:
  - Land caps 2→**3** base / 5→**7** max; land spawn interval 6→**4.5s** — banks feel alive with threats.
  - Land ambushers anchor a bit **into the treeline** (fork-aware outer edge + 8–20 studs) so they emerge from
    the forest.

## Verified (live in Studio — Play)
- [x] Analyzer-clean.
- [x] Foliage: ~395 trees streamed near the boat (thick wall); screenshot shows a dense treeline with the
      channel clear as the corridor.
- [x] Land threats: reached the new base cap of **3** near the start within 12s of a run (was 2), spawning
      faster.

## Notes / follow-ups
- **Not committed.**
- Land enemies move at `WATER_Y`; anchoring only 8–20 studs inland keeps them at the shoreline (no burying in
  the bank). Deeper "forest" enemies would need terrain-height movement — out of scope for greybox.
- Landing clearings here are just foliage; the full **clear path + camp roster** is #5.
- Next: **#5 camp rework** (clear disembark path + predefined non-respawning escalating rosters), then
  **#6 pacing/optional stops**.
