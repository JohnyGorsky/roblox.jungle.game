# Job #077 — WORK IN PROGRESS state (saved 2026-08-06)

**Not finished.** Code is written, analyzer-clean and syncing, but there are **known open bugs** listed
below. Nothing is committed (per the never-commit rule) — everything is in the working tree.

---

## What is DONE and verified in Studio

| Piece | State |
|---|---|
| `sync/ServerScriptService/World/CampDefs.luau` | **new** — the dressing table (models, per-model scale, layout slots, clearing ring, ground weights, VFX/light budgets, audio ids, tags) |
| `sync/ServerScriptService/World/Campfire.luau` | **new** — rock ring + crossed logs + Fire/Smoke/embers/PointLight/crackle |
| `sync/ServerScriptService/World/CampAmbience.luau` | **new** — fireflies (night) / motes (day), 3 practicals, shared phase-gate + fire-flicker tasks |
| `DockServer.server.luau` | real `Dock` model; `Deck` kept as an INVISIBLE anchor so `TieSpot`/rope/prompt geometry is unchanged; deck height MEASURED at runtime; pilings below water made non-colliding; water + rope-creak audio |
| `ExcursionServer.server.luau` | camps re-dressed from `CampDefs`; crates/nugget/carried-crate on real models; ground paint pass; trading post = `BahayKubo7` + physical sign |
| `FoliageDefs.luau` | `worldBottom` now includes the instance itself; `seatOnGround` takes `PVInstance`; **new** `groundClearFraction` |
| Verified live | all 19 library models resolve (0 warnings); loot/tie prompts + attributes intact; basin flat 17–18; 22/26 props seated at exactly −0.30; `tools/luau-analyze.sh` clean |

## Bugs FOUND and FIXED during the playtest

1. **`GoldNugget` never spawned.** It is a bare `MeshPart`, not a Model; the library scan and `prop()`
   were Model-only, so it silently returned nil *and still burned a capped nugget slot*. `prop()` now
   returns `PVInstance` and handles single parts.
2. **`Tent` at 43×34 studs** read as a giant beige tarp bigger than the huts → `CampDefs.SCALE`.
3. **Camps built on terrain that did not exist yet.** `RiverBootstrap` streams chunks ~1800 studs ahead
   and culls the rest; `ExcursionServer` built sites up to 1400 ahead and `ForceFirstCamp` ~1900 ahead.
   Result: every `groundAt` fell back to `CLEAR_Y`, all 24 props seated at 14.7, then the generator wrote
   the real hillside (22→48) over them — "structures underground". Fixed with `terrainReadyAt()`, which
   refuses to build (and does not mark `built[]`) until terrain is there; `ForceFirstCamp` now polls.
4. **"Land is outside".** `carve()` was ONE 400×400 `FillBlock` using the bank sampled at a single Z.
   The river meanders, so the square filled the channel with solid ground. Now carved in 20-stud Z
   slices that re-read the bank each slice. The mud bank paint is sliced the same way.
5. **Canopy in the river.** The first clearing ring tiled `JungleTreesPack` (218 studs long) — half of
   each tile landed in the water. Replaced with individual cheap trees (see below).

## 🔴 OPEN BUGS — start here

1. **`Tent`, `Barrel` and `AmmoBox` float in mid-air** (~15 studs up) while `BahayKubo*` and the campfire
   seat correctly. Last screenshot from the user shows it clearly. **Diagnosis was in progress and is
   NOT done.** The measurement script to re-run is in the transcript; it dumps, for each of
   `Tent` / `Barrel` / `LootCrate` / `BahayKubo5`: pivot Y, `worldBottom`, ground Y, and every
   BasePart's position/size — plus the same for the *unscaled library source*.
   Leading hypothesis: these models contain a part (or a mesh whose geometry does not fill its
   `Size` box) well below the visible geometry, so `worldBottom` seats *that* on the ground and leaves
   the visible mesh high. If so, the fix is to seat on a *robust* bottom (e.g. ignore parts that are
   far below the bulk of the model, or use a percentile rather than the true minimum).
2. **The clearing ring rewrite is UNVERIFIED.** It was switched from `JungleTreesPack` to individual
   trees (`PalmCoconut`/`PalmLowPoly`/`BushPack`/`FernTall`, 2 staggered rows) and the analyzer passes,
   but it has **not been run once** — the last Studio call errored before the rebuild.
3. **Nugget spawn still never observed** (`NUGGET_CHANCE` is 0.25/camp, so it may simply not have
   rolled). Force it by temporarily raising the chance, and confirm the mesh seats and the prompt works.

## Root cause worth remembering

**Nearly every placement bug in this job was the same mistake: one sample used to validate a large
footprint.** One raycast for a 43-stud tent, one bank sample for a 400-stud basin, one bank sample for a
218-stud canopy tile. The models here are 20–218 studs across; a point test cannot validate them.
`FoliageDefs.groundClearFraction` is the shared fix, and `FoliageServer` already had its own version of
this lesson written in a comment (trunk-footprint test) that the rest of the codebase did not follow.

## Deliberately NOT changed (needs a decision)

- **The shelf artifact.** `roblox-terrain` §4: no land surface may sit between `WATER_Y` and
  `WATER_Y + 8`, or it renders as thin hole-riddled sheets. But `RiverGenerator` ramps the bank up from
  *exactly* the waterline (`lip = min(edge*0.6, BANK_LIP)`), so the first ~13 studs of every bank are in
  that band, and `FoliageServer.MIN_GROUND_Y_ABOVE_WATER = 1` lets foliage plant right there. This is a
  strong candidate for "rocks look like they float at the shore".
  **Not changed because** raising `MIN_GROUND_Y_ABOVE_WATER` to 8 would delete the palm ALLEY (its band
  is `inland = {1,7}`), which is a signature feature, and changing `BANK_LIP` alters the look of all
  18,000 studs of river. **This is a Job #076 decision and needs the user.**
- **Chunk culling vs built camps.** `cullChunk` clears terrain 2 chunks (~500 studs) behind the boat,
  but a landing site is only destroyed at `CULL_BEHIND` (1200). Between those, a camp's terrain is gone
  while its models remain. Players have usually left by then, so it was left alone.

## Verification still outstanding (plan Part 11)

Ride → tie → ashore → raid → haul → untie end to end; loot/kind-crate/nugget grants; hauling feel;
`UntieButton` path; boat does not explode on the pier; night pass + `NightLight` switch at 17.5 h;
smoke column read **from the boat**; Device Emulator with #076 foliage live.

## Bookkeeping not yet written

`ASSETS.md` §3.5 statuses, `Planned/camp-night-practicals.md` (camp half delivered, ambient half still
open), `final-summary.md`, `changelog.md`, and the intake checklist.
