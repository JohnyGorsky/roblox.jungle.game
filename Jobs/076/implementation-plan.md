# Implementation Plan — Job #076

**Project**: `roblox.jungle`
**Created**: 2026-08-05
**Status**: Planning — awaiting build go-ahead. **Builds FIRST** (user decision A4, 2026-08-05): this job
sets the frame budget everything else fits under, and it owns the camp trees — so dressing camps
([#077](../077/implementation-plan.md)) first would mean re-dressing camps still full of greybox trees.

## Decisions taken (wizard + the hand-built reference shot)

| | |
|---|---|
| **Assets** | **Reuse what exists. No new models.** See "why nothing is needed" below. |
| **Alley** | Leaning palms over the water, **sparse — not dense** (user, revising the earlier "every 20 studs") |
| **Band 2 vs 3** | Line 2 = individual palms you can see between · Line 3 = `JungleTreesPack` tiled as a solid canopy wall |
| **Scope** | Terrain materials + the three foliage bands + the river's greybox obstacles. Camp **structures** and enemies stay greybox for their own jobs. |

The starting area the user hand-built **is the target look**, and it is also the proof the existing library
is sufficient: bright chunky palms near the water, a dark packed palm forest behind, sand beach into
grass. Everything in that shot comes from `ServerStorage.AssetLibrary`.

---

## Part 1 — Why no new assets are needed

The audit asked whether we need new objects. **We don't**, and the reason is that the cheap model is the
one that carries the look:

| Model | Instances | Role |
|---|---|---|
| `PalmCoconut` | **4 meshes**, 44×50×38 | **The hero shore palm.** The big bright chunky tree in the reference shot. Cheap enough to be the workhorse. |
| `BushPack` | 8 meshes | shore undergrowth |
| `FernTall` | 1 mesh | ground leaf, densest filler |
| `PalmLowPoly` | 3 | small/young palm (the little ones in the shot) |
| `LogMossy` | 1 mesh | fallen log, shore punctuation |
| `RockA/B/C` | 1 mesh | all bands + obstacles |
| `JungleTreesPack` | 112, **218 studs long** | **Band 3 wall.** Not a tree — a pre-arranged cluster. Tiled, not scattered. |
| `PalmCurved` | ⚠️ 63 parts | **alley accent only**, sparse |
| `PalmTall` | ⚠️ 65 parts | band-2 accent only, sparse |

My earlier recommendation to source MeshPart palms was **premature**. It assumed a dense alley; a sparse
one makes the two heavy models garnish rather than the bulk, and the budget below closes without them.

**Sand, Grass and LeafyGrass are built-in `Enum.Material` values** — the material work needs no assets at all.

> ⚠️ **The library is NOT in git.** `sync/ServerStorage/` contains only `Inventory`; `AssetLibrary` is
> authored in the **place file**. So the generator must look it up at runtime and **fail loudly** if a
> model is missing, the way `StartShopServer` does for the editor-placed kiosk — a silent nil here would
> mean an empty jungle with no clue why.

## Part 2 — The perf budget (the real constraint)

`FoliageServer` keeps a **1020-stud window** live (`AHEAD 800` + `BEHIND 220`) and currently fills it with
~816 two-part greybox trees ≈ **1,630 parts**. Real models are heavier, so density is derived from a
budget rather than picked:

| Band | Inland | Model | Spacing per bank | Live | Instances |
|---|---|---|---|---|---|
| 1 | 0–35 | `PalmCoconut` | 30 | 68 | 272 |
| 1 | 0–35 | `BushPack` | 25 | 82 | 656 |
| 1 | 0–35 | `FernTall` | 20 | 102 | 102 |
| 1 | 0–35 | `PalmLowPoly` | 50 | 41 | 123 |
| 1 | 0–35 | `LogMossy` | 120 | 17 | 17 |
| 1 | 0–35 | `RockA/B/C` | 40 | 51 | 51 |
| 1 | waterline | **`PalmCurved` (alley)** | **80** | 25 | **1,575** |
| 2 | 35–110 | `PalmTall` | 100 | 20 | **1,300** |
| 2 | 35–110 | `PalmCoconut` | 40 | 51 | 204 |
| 2 | 35–110 | `FernTall` + rocks | 45 | ~90 | ~140 |
| 3 | 110–220 | **`JungleTreesPack`** (tiled) | 218 | 10 | 1,120 |
| | | | | | **≈ 5,560** |

**~3.4× today's greybox cost, for real art.** Worth stating plainly: the two part-built palms are
**2,875 of those 5,560 instances — over half the budget from 45 objects.** If perf bites on a real
device, they are the first and most obvious lever, and swapping them for MeshPart equivalents later is a
one-line change per entry in the band table. That is why sourcing them now would be solving a problem we
may not have.

Mitigations applied on top: `Model.LevelOfDetail = StreamingMesh` where it helps, `RenderFidelity`
left Automatic, one `Folder` per chunk so culling is a single `Destroy`, and every model
`Anchored`/`CanCollide=false` except where collision is wanted (logs, rocks).

## Part 3 — Terrain materials

`RiverGenerator:117-133` currently paints **Grass everywhere**, Rock above y=26, Snow above y=40 — and
**the riverbed is Grass**, which is simply wrong. New bands, from the channel outward:

| Zone | Material now | Material after |
|---|---|---|
| Riverbed (below water) | Grass | **Sand** |
| Water column | Water | Water (unchanged) |
| Shore strip (bank edge → ~30 studs inland) | Grass | **Sand**, fading into grass |
| Jungle floor | Grass | **Grass + LeafyGrass**, mixed by low-frequency noise |
| Above y=26 | Rock | Rock (unchanged) |
| Above y=40 | Snow | Snow (unchanged) |

The Grass/LeafyGrass mix is noise-driven, not alternating, so it reads as patchy ground rather than a
pattern — STYLEGUIDE §4: *"never flat-coloured — mix sand, dirt, mud, grass patches."* The sand→grass
boundary gets the same treatment so the beach edge isn't a clean line.

This is a **one-pass change inside the existing `writeChunk`** — the material choice is already a
per-voxel branch, so no new terrain writes and no cost change.

## Part 4 — The alley

Leaning palms placed **at the water's edge, tilted out over the channel**, sparse (~1 per 80 studs per
bank, offset between banks so they alternate rather than pair up).

- Placed from the **same seed** as everything else, so a given river always has the same palms.
- Tilt is toward the channel centre, derived from `RiverData.centerlineX` — so on a bend they lean the
  correct way rather than in a fixed world direction.
- Tilt angle randomised in a range, not constant, so they don't read as a planted colonnade.
- **Kept off the driving line.** Fronds may overhang; trunks stay on land. The driver's sightline into
  the next bend is the thing steering skill depends on, so the alley frames the channel rather than
  closing it.

## Part 5 — Greybox removal (this job's scope)

| Greybox | Where | Becomes |
|---|---|---|
| 2-part trunk+canopy tree | `FoliageServer:94,102` | the band system above |
| `Rock` obstacle box | `RiverBootstrap` OBSTACLES | `RockA/B/C` |
| `Log` obstacle box | " | `LogMossy` |
| `Sandbar` obstacle box | " | flattened `RockA` + terrain Sand |
| Camp trees (`TREE_COUNT = 45`) | `ExcursionServer:269` | the same band picker |

> **One scope judgement, stated rather than made quietly:** the wizard answer excluded the dock camps,
> but `ExcursionServer` plants **45 greybox box-trees per camp** — that is *foliage*, and leaving it
> would put greybox trees at all six landings in an otherwise real jungle. So camp **foliage** is in
> (it reuses the picker; one call site).
>
> Camp **structures** — huts, loot crates, trading post, gold nugget, and the docks — are
> **[Job #077](../077/intake.md)**, created 2026-08-05 with its asset audit done. The two jobs share the
> six landings and both spend from the same frame budget, so #076's instance count is the ceiling #077
> has to fit under.

**Obstacles must stay non-colliding triggers.** `RiverBootstrap`'s own comment: *"physical collision
would blow up the boat assembly."* The swap is visual only — `CanCollide = false`, the `Obstacle` tag and
the `Slow`/`Damage` attributes carry over untouched.

## Part 6 — Files

**New**
| File | Purpose |
|---|---|
| `sync/ServerScriptService/World/FoliageDefs.luau` | the band table: model name → band, spacing, scale/tilt jitter, collision. **The one place a density number lives.** |

**Rewritten** — `sync/ServerScriptService/World/FoliageServer.server.luau` (band-aware placement from
`AssetLibrary`, per-chunk folders, budget-capped)

**Edited**
| File | Change |
|---|---|
| `sync/ServerScriptService/River/RiverGenerator.luau` | Sand riverbed + sand shore + Grass/LeafyGrass mix |
| `sync/ServerScriptService/River/RiverBootstrap.server.luau` | obstacles use real models |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | camp trees use the picker |
| `ASSETS.md` | §1.1 gains a game-place river-foliage section + the band table |

**Untouched:** the boat, the HUD (Job #075), camp structures, enemies, the spawn-base exclusion logic
(`FoliageServer` already measures the hand-built camp's footprint and keeps clear of it — that stays, and
it is why the hand-dressed starting area will not be disturbed).

## Part 7 — Verification

- **Play, and ride the river** — screenshot each band boundary at a straight stretch and at a bend
  (the bend is where a naive band offset breaks).
- **Compare against the reference shot** — bright palms near, dark pack behind, sand into grass.
- **Instance count in Play**: `#Workspace.Foliage:GetDescendants()` sampled while moving, against the
  ~5,560 budget. A number well over it means a spacing bug, not a heavy model.
- **Confirm the hand-built starting area is untouched** — the camp exclusion still holds.
- **Confirm obstacles still hurt**: ride into a rock, check hull drops and the boat doesn't explode.
- **Device Emulator** for frame time with the full band system live — this is the job most likely to
  cost frames, and it lands on top of Job #075's still-unverified mobile pass.
- `tools/luau-analyze.sh` clean.

---

# Build log — 2026-08-05

**Built and verified in Studio Play. Not closed** — user asked to build, then test and adjust.

## Shipped

| | |
|---|---|
| `FoliageDefs.luau` | new — the band table, plus `worldBottom` / `seatOnGround` helpers |
| `FoliageServer.server.luau` | rewritten — 3 bands + the alley + the tiled wall, from `AssetLibrary` |
| `RiverGenerator.luau` | Sand riverbed · noise-jittered Sand shore · LeafyGrass-dominant jungle mix |
| `RiverBootstrap.server.luau` | obstacles use `RockA` / `LogMossy` with a per-type `submerge`; greybox kept as fallback |
| `ExcursionServer.server.luau` | camp trees draw from the same shore band |

**Measured live: ~5,666 parts in the 1020-stud window** against the planned ~5,560 — within 2%.

## Four bugs found by playtesting, all fixed

1. **`Model.LevelOfDetail` is not writable from a server script** (needs the Plugin capability) — it threw
   once per placement. Now set ONCE at authoring time on the `AssetLibrary` source models, where Studio
   *does* have the capability; clones inherit it.
2. **The instance count was wrong, not the density.** First run reported "~21420 instances" against a
   ~5,560 budget, which looked alarming and wasn't: `#GetDescendants()` counts SurfaceAppearances,
   Attachments and Textures too. `instancesOf` counts **BaseParts** now — the thing that costs frames.
3. **🐛 Obstacle rocks hovered over the river** (user: *"why do we have rocks on water :D"*). The art was
   positioned by PIVOT at the trigger's centre; store pivots are arbitrary. Now seated by true world base
   with a per-type `submerge` fraction — Rock 0.55, Log 0.35 — and the invisible trigger follows the art
   so the hit box and the thing you swerve around are in the same place. Verified: Rock base 7.2 / top
   15.9, Log 10.7 / 14.4, against `WATER_Y` 12.
4. **🐛 Camp flora was buried 2.4 studs.** It trusted `CLEAR_Y` (15) as the ground height, but terrain
   voxels snap to the `RES = 4` grid so the real surface is ~17. It **raycasts** now. Measure, don't assume.

> ### ⚠️ The mistake worth remembering
> Bugs 3 and 4 were both the same root error, and this file's own `FoliageServer` comment had warned about
> it since Job 072: **`Model:GetBoundingBox()` returns the ORIENTED box and lies about world occupancy.**
> The first pass used it to seat models anyway, which put every tilted model — i.e. the whole alley — up to
> +0.57 studs off the ground. There is now one shared `FoliageDefs.worldBottom` that walks part CORNERS,
> used by all three seating paths. **Verified after the fix: all 11 riverbank model types sit at exactly
> −0.40, the intended sink, alley palms included.**

## Known, not yet addressed

- **`Sandbar` obstacles are still greybox boxes** (deliberate — a flat shoal wants to be a flat slab), but
  under the teal water they read as dark red planks rather than sand. Wants either a better colour or a
  flattened `RockA`.
- **~2 of 41 camp placements still land ~2.4 studs low**, where the ground raycast hits a basin *wall*
  (walls are terrain) instead of the floor. Needs the raycast to reject near-vertical hits.
- **Mobile not tested.** ~5,666 parts is a desktop-comfortable number and an unknown on a phone. This
  lands on top of Job #075's still-unverified mobile pass.
- `ASSETS.md` §3.4 statuses stay "planned" until after the tuning pass.
