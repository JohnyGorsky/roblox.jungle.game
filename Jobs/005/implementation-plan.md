# Implementation Plan — Job #005: River Terrain Generator

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: ✅ Completed (2026-07-18) — see final-summary.md

## Goal

Replace the one-off baked river with a **reusable, seeded, chunk-streamed** river+terrain generator that
produces a **long, WIDE** river (Dead-Rails-length), with a **logical END** at a configurable distance and
a **distance-traveled** readout. The boat reads the river's centerline/width from **shared data** instead
of a hardcoded table.

## Decision (from design reasoning — game-design skill)

**Seeded + chunk-streamed, with a hard logical END.** Rationale:
- "Long like Dead Rails" ⇒ generating the whole river at once is too much voxel volume for mobile
  (load time + memory) ⇒ streaming is required anyway.
- A logical **END at `END_DISTANCE`** gives a win condition + escalating zones + a finish (Dead Rails
  shows distance and ends at a set distance). Same streaming tech ⇒ **P10 endless** later is nearly free
  (move/remove the end).
- **Seeded** ⇒ reproducible runs; random per run now, shared **daily seed** for fair leaderboards later.

## Architecture

**1. `RiverData` (ReplicatedStorage ModuleScript) — the single source of truth.**
Pure math, deterministic from `(seed)`. No terrain writes. Exposes:
- `centerlineX(distance) → number` — meandering X as a continuous function of downstream distance
  (layered value-noise/sines seeded by `seed`; continuous ⇒ chunk seams line up automatically).
- `widthAt(distance) → number` — WIDE by default (~140–200 studs), occasional **narrows** (~60) as
  pinch-points via a separate low-freq noise; possible **forks** later.
- `tangent(distance) → Vector3`, `WATER_Y`, `END_DISTANCE`, `positionAt(distance) → Vector3`.
- `distanceToWorld` / `worldToDistance` helpers so the boat maps its Z/position ↔ river distance.

**2. `RiverGenerator` (ServerScriptService) — voxel materialization + streaming.**
- Works in **chunks** of `CHUNK_LEN` (e.g. 256 studs of downstream distance).
- Per chunk (using `roblox-terrain` discipline — compute geometry → **carve then fill** → **read-back
  verify**): base grass, **carve the channel** to `widthAt`, fill **terrain water** to `WATER_Y`,
  flanking **noise hills** with altitude-painted materials (grass→rock→snow), and deterministic
  **obstacle/ramp placement hooks** (markers/attachments along the channel; the props come later).
- **Streaming loop:** track the boat's river-distance each step; ensure chunks in
  `[dist - BEHIND, dist + AHEAD]` exist; **cull** (clear terrain) behind. Spread voxel writes across
  frames to stay within budget (`roblox-optimization`).
- **END:** at `END_DISTANCE` generate a finish/dock set-piece and stop generating forward (campaign
  mode); an `ENDLESS` flag skips the end for P10.

**3. Boat refactor (`BoatServer`).**
- Delete the hardcoded `CENTERLINE`; `require(RiverData)`.
- `downstream(z)` → `RiverData.tangent(worldToDistance(z))`; spawn at `RiverData.positionAt(0)`;
  `WATER_Y` from `RiverData`. No more measured-constant desync.

**4. Distance readout.**
- Server tracks boat river-distance; expose via attribute for a later HUD (score = distance + zones).

## Seed & config
- `seed` from a Workspace attribute / config (random per run now; daily-seed hook later).
- Tunables: `CHUNK_LEN`, `AHEAD`, `BEHIND`, width range, narrow frequency, `END_DISTANCE`, hill params.

## Build & verify order (incremental, each verified via MCP before the next)
1. `RiverData` math — unit-check continuity across chunk boundaries + width profile (print samples).
2. `RiverGenerator` single chunk at origin — **voxel read-back verify** (channel carved, water at
   `WATER_Y`, hills painted), screenshot.
3. Multi-chunk + seam continuity — verify no gaps/steps at boundaries, screenshot a long stretch.
4. Streaming follow + cull behind — drive the boat, confirm chunks appear ahead / clear behind, watch
   `GetNumAwakeParts`/frame budget.
5. END set-piece at `END_DISTANCE`; distance attribute.
6. Boat refactor to `RiverData`; re-run the #003 drive-test (still floats, routes, feels right on the
   WIDE channel).

## Risks
- **Chunk seams** — mitigated by a *continuous* centerline/width function (materialize per chunk, don't
  regenerate independently).
- **Voxel write cost** while streaming on mobile — spread writes across frames; tune `CHUNK_LEN`/budget.
- **Wide channel vs boat feel** — re-tune boat drift/turn for the wider river after the refactor.

## Success test
- [ ] A long, wide, winding seeded river streams as the boat rides; same seed → same river.
- [ ] Obstacle/ramp placement hooks exist along the channel.
- [ ] A logical END with a finish set-piece at `END_DISTANCE`; distance-traveled tracked.
- [ ] Boat reads `RiverData` (no hardcoded centerline) and still feels good on the wide channel.
- [ ] Streams within a sane mobile frame/memory budget.

## Notes
- Terrain lives in Workspace/Terrain (not auto-synced) — **user saves the place** to persist a baked
  reference if desired; the generator rebuilds from seed regardless.
- Scripts on disk under `sync/` auto-sync; run `bash tools/luau-analyze.sh` after each edit.
- **Forward-compat (future — GAME.md "Land excursions"):** later we'll add **landing sites** where the
  river widens onto walkable coast/village terrain (camps to raid). Keep `RiverData`/`RiverGenerator`
  **mode-aware** (a per-distance "zone/biome" concept) so a wide POI mode can slot in beside the river
  mode without a rewrite — see `Planned/land-excursions-camps-villages.md`. Not built in #005.
