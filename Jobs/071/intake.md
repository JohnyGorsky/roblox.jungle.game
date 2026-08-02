# Job #071: GAME terrain — hand-sculpted START and END joined to the generated river

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: **Design discussion — nothing built yet.** Decisions needed before any terrain is touched.

## What you asked for

> *"start and end is terrain in editor so I can edit it… we need exact terrain with textures. Only
> exception — no airfield. That way we can populate start area where plane crashes and end area where
> we get out and get rewards. So we need to think how we generate these areas in editor, then how we
> generate terrain in game so it matches both ends."*

Per the sketch: **two hand-built bulbs** (start left, end right) joined by a **generated river
corridor**, with a **junction** at each red mark.

This matches GROUND-RULES §2 exactly — *"Hand-sculpt hero/handcrafted terrain… Claude scripts
PROCEDURAL terrain only"* — and `StagingServer` already anticipated it in a comment:

> *"the greybox hub here is a PLACEHOLDER — the human will hand-build the real crash-site hub +
> startup river; a later job points the procedural generator at **HANDOFF_Z**."*

`HANDOFF_Z` exists today as `RiverData.Z_START + 300`, asserted and then **used by nothing**. This job
makes it real — at both ends.

---

# Part 1 — What is actually there now

| | |
|---|---|
| Terrain in the game place | **present** — 52,416 occupied voxels probed across the corridor (z −500…2500) |
| `Workspace` contents | `Terrain`, `SpawnLocation`, `Camera` — `EditorPiers` is **gone** (you cleaned it) |
| Boat art | ✅ migrated and verified (Job #070) |

The corridor terrain is leftover generator output. **It has to go** — see constraint C2.

# Part 2 — The four constraints that decide the design

## 🔴 C1 — The river's shape CHANGES EVERY RUN

This is the one that shapes everything else.

`RiverData.centerlineX(z)` and `widthAt(z)` are both **seed-derived** — `Random.new(seed)` produces
`offX1/offX2/offX3/offW`, which offset the Perlin noise. The seed is **random per run** (GAME.md:
*"random per run, or a shared daily seed"*).

**So the channel's X position and width at any given Z are different every single run.** Hand-sculpt a
start area that fits today's river and tomorrow's run puts the channel somewhere else. At `A1 = 300`
the big course bend alone swings **±300 studs** side to side, before the medium and fine octaves.

**Any design that ignores this produces a seam that works once and then breaks.**

## 🔴 C2 — `RiverBootstrap` wipes ALL terrain on boot

`RiverBootstrap.server.luau:154` — `Workspace.Terrain:Clear()`.

Harmless today (everything is procedural) and **fatal the moment terrain is hand-sculpted**: every
server start would erase both hand-built areas. This must become a *targeted* clear, or no clear at all.

## 🟠 C3 — Generated chunks are big, and would overwrite the ends

`RiverGenerator.chunkRegion(i)` spans:
- **Z**: `Z_START + i·256` … `+256` (`CHUNK_LEN = 256`)
- **X**: centerline ± (`MAX_HALFW` 170 + `LAND` 220) = **±390 studs**
- **Y**: −8 … 64

Any chunk overlapping an editor zone rewrites it. Chunk generation must **skip protected Z ranges**.

## 🟠 C4 — The junction must match on six properties, not one

For an invisible seam, the generated side and the sculpted side must agree on:

| Property | Source | Seed-dependent? |
|---|---|---|
| Water surface Y | `WATER_Y = 12` | ✅ fixed — free |
| Channel centre X | `centerlineX(z)` | ❌ **varies** |
| Channel width | `widthAt(z)` | ❌ **varies** |
| Channel depth | `CHANNEL_DEPTH = 18` below water | ✅ fixed |
| Bank lip height | `BANK_LIP = 10` | ✅ fixed |
| Land height + material bands | hill noise, `ROCK_Y 26` / `SNOW_Y 40` | ✅ fixed offsets, but positioned *relative to the channel* |

Only two vary — but they are the two that matter most.

---

# Part 3 — Proposed architecture

## Core idea: **seed-lock the ends, generate the base, sculpt on top**

Three pieces that together solve C1 and C4.

### 3.1 Seed-lock a band at each end

Add a lock to `RiverData`: inside a band next to each editor zone, `centerlineX` returns a **fixed** X
and `widthAt` a **fixed** width, then blends smoothly to the seeded values over a transition
(~600–1000 studs):

```lua
local k = RiverData.lockFactor(z)          -- 1 = fully locked, 0 = fully seeded
return (1 - k) * seeded + k * LOCK_CENTER_X
```

**The junction geometry then becomes identical for every seed**, so one hand-sculpt fits all runs. The
river still meanders freely across the entire middle — the lock touches only the two approaches, and a
river running roughly straight for a few hundred studs out of a crash site and into a delta reads
perfectly naturally.

### 3.2 Generate the editor base with the same generator, then sculpt on top

Rather than sculpting the junction freehand and hoping it lines up:

1. Run `RiverGenerator` **in the editor** across each end zone (a one-shot build script).
2. **Sculpt on top** of that output — widen the bay, carve the crash site, raise hills, paint materials.
3. **Leave roughly the 64 studs nearest each seam untouched**, so the boundary voxels stay exactly what
   the generator produces.

The seam then matches **by construction rather than by eye** — the editor terrain *started as*
generator output at precisely the right profile, water level, depth and bank lip.

### 3.3 Runtime protects and skips the editor zones

- `RiverData` gains protected ranges — e.g. `START_ZONE_Z_END`, `END_ZONE_Z_START`.
- `RiverBootstrap` drops `Terrain:Clear()`. The saved place ships with **only** the two end zones and an
  empty corridor, so there is nothing to clear at boot.
- `ensureChunk(i)` / `clearChunk(i)` skip any chunk overlapping a protected range.

## What this means for the run

| Zone | Z range (illustrative) | Built by | Contents |
|---|---|---|---|
| **START** | −1200 … 0 | **you, in the editor** | crash site, wrecked plane, moored boat, first supplies. **No airfield.** |
| *lock → blend* | 0 … ~800 | generator, locked then blending | straight-ish river leaving the crash site |
| **MIDDLE** | ~800 … ~17200 | generator, fully seeded | the run: 4 zones, docks, obstacles, forks |
| *blend → lock* | ~17200 … 18000 | generator, blending back to locked | river settling into the delta |
| **END** | 18000 … 19200 | **you, in the editor** | extraction point, rewards, the win moment |

Note the end zone sits in **Lost Delta** (`width = 300`, the widest profile), so the locked width there
should be generous — a narrow locked channel would look wrong against the delta it emerges from.

---

# Part 3b — MEASURED: the lobby as the start-area template (2026-08-02)

Decision taken: **the start area is lobby-sized, the airstrip goes, and the lobby's water inlet widens
into the river mouth.** Measured the lobby terrain live to get real numbers rather than eyeballing:

| Property | Lobby (measured) | Game river | Verdict |
|---|---|---|---|
| Footprint X | −378 … 598 = **976 studs** | corridor is ±390 | ✅ ~2.5× the corridor, matches the sketch |
| Footprint Z | −598 … 302 = **900 studs** | — | ✅ |
| **Water surface Y** | **−6** | **`WATER_Y = 12`** | 🔴 **18-stud mismatch** |
| **Highest land Y** | **98** (mountain backdrop) | `Y_MAX = 64` | 🔴 **34 studs above what the generator can build** |
| Water inlet span | X 118…394, Z 2…102 | channel is 150 wide at Headwaters | ⚠️ needs widening, as you said |
| Materials | Snow 30k · Rock 13k · Grass 9.4k · Sand 4k · LeafyGrass · Water · Mud | generator paints Grass/Rock/Snow by altitude | ✅ same vocabulary |

## 🔴 Two mismatches that would show as a hard step at the seam

**1. Water level.** The lobby sits at Y −6, the river at Y +12. Three ways to resolve:
   - shift the copied terrain **up 18 studs**;
   - change `RiverData.WATER_Y` to −6 (touches the whole river, boat buoyancy, dock heights);
   - re-level the lobby water before copying.

**2. Vertical range.** Lobby mountains reach Y 98; `RiverGenerator` spans `Y_MIN −8 … Y_MAX 64`. The
corridor's hills would top out 34 studs below the start area's backdrop. Either raise the generator's
ceiling (costs voxels per chunk, and `HILL_MAX` is only 42 anyway) or accept that the tall mountains
are an end-zone feature that fades out along the corridor — which is arguably correct: GAME.md wants
*"big rock/snow mountains far in the distance"*, not lining the channel.

## How terrain actually moves between places

Terrain is voxels, not instances — there is no Explorer copy-paste for it. The workable route is
`Terrain:CopyRegion(region)`, which returns a **`TerrainRegion` instance** that *can* be copy-pasted
between the two open Studio windows, then `Terrain:PasteRegion(...)` in the game place. Roughly 1.9M
voxels at the lobby's size, so it may need splitting into a few regions.

*(`CopyRegion`/`PasteRegion` are deprecated but functional; `ReadVoxels`→`WriteVoxels` across places is
not viable — the array is far too large to move through a tool call.)*

# Part 5 — AGREED PLAN (decisions taken 2026-08-02)

| Decision | Choice |
|---|---|
| Start terrain | **Copy the lobby's actual terrain**, then edit it — keeps the existing sculpt, materials, mountains and shore |
| Water level | **Shift the copied terrain +18 studs** so its surface lands on `WATER_Y = 12`. `RiverData` untouched; the lobby place untouched |
| Placement | **START zone at Z −900 … 0.** The generated river still begins at `Z_START = 0`, so no constant, chunk index, dock spacing or distance maths changes |
| Airstrip | **Removed** |
| River mouth | The harbour is **widened and carved north to the Z = 0 boundary** |

## The transform

| Axis | Offset | Why |
|---|---|---|
| **X** | **−302** | harbour centre X 302 → **0**, so the mouth sits on the locked centreline |
| **Y** | **+18** | water surface −6 → **12** |
| **Z** | **−302** | lobby Z −598…302 → game **−900…0**, junction exactly at Z 0 |

Region copied: cells `(−100,−10,−155)` … `(155,28,80)` = studs `(−400,−40,−620)` … `(620,112,320)`,
**2.28M cells**, `SizeInCells = 256×39×236`.
Paste corner in the game place: **`(−702, −22, −922)`**.

## 🔴 The harbour is a closed bay pointing the wrong way

The fine probe found the water at **X 114…490 (376 wide), Z −10…194 (only 204 deep)**, and it **never
reaches the map edge** — land continues to X 598 on every probed row.

So it is an **enclosed bay running east–west**, while the river flows **north–south along Z**.
`PasteRegion` cannot rotate. Two consequences:

1. The mouth must be **carved north** from the bay to the Z = 0 boundary — this is the *"widen the
   lobby river"* work, and it is hand-sculpting, not something to script.
2. After the shift, the bay sits at roughly **Z −312 … −108**, i.e. 108–312 studs south of the
   junction. That is a comfortable distance to carve a natural-looking channel through.

## ✅ DONE 2026-08-02 — paste, cleanup, and the code guards

### Paste
`PasteRegion` at cell corner `(−175, −6, −230)`. **Corrected my own arithmetic mid-flight:** the corner
is in *cells* (4 studs), so offsets must be multiples of 4 — `+18` is impossible. And comparing a voxel
*centre* to a water *level* was the wrong measure: the lobby's top water voxel spans −8…−4 and the
generator fills to exactly Y 12, so the true offset is **+16**, which *is* a clean 4 cells.

Result: **water surface exactly Y 12**, zone X −678…358, Z −898…~20, all materials carried
(Snow 138k · Rock 62k · Grass 50k · Sand 20k · LeafyGrass · Mud · Ground), mountains to Y 118.

### Corridor cleanup
Old generator terrain ran **Z 28 → beyond 6000**. Cleared with 50 Air-filled slabs; **0 voxels remain
past Z 24**, start zone intact at 71,153.

*First attempt silently did nothing* — it pre-checked each slab with `ReadVoxels` over ~9.6M-voxel
regions, which exceeds the API limit, so the call failed, the count stayed 0 and every slab was
skipped. Fixed by filling unconditionally in smaller slabs.

### Code guards

| File | Change |
|---|---|
| `RiverData` | `START_ZONE_Z_END` / `END_ZONE_Z_START` / `LOCK_CENTER_X` / `LOCK_WIDTH_*` / `LOCK_BLEND` + `lockFactor()`; `centerlineX` and `widthAt` blend seeded → locked; forks suppressed inside a lock band |
| `RiverGenerator.chunkRegion` | **clamps** Z to the zone boundaries. Clamping not skipping, because 18000/256 = 70.3 — skipping chunk 70 would leave an 80-stud hole |
| `RiverBootstrap` | **`Workspace.Terrain:Clear()` removed**, with a comment on why it must not come back |

### Verified — seed independence (5 seeds: 2026, 7, 999999, 31337, 555)

| z | centreline spread | |
|---|---|---|
| **0** | **0.00** | ✅ locked, width 150.0 |
| 100 | 12.8 | blending |
| 400 | 142.8 | seeded |
| 1600 | 370.5 | fully seeded |
| **18000** | **0.00** | ✅ locked, width 300.0 |

Forks: none on any seed at z 0, 400, 17600, 18000.

### Verified in Play

- 🔴 **The hand-sculpted zone survives a server boot** — solid terrain at z −800…−60 and the bay water
  at z −200. This is the `Terrain:Clear()` removal proven, and it was the highest-risk change.
- **The seam matches**: at z 0 the generated water spans X −74…74 — centre **0**, width **148** vs the
  locked 150 — with the surface at exactly **Y 12**. Same at z 40. It then drifts seeded as designed
  (z 600 centre −166).

### ⚠️ Two things this exposes for the sculpting

1. **Sculpt only at z < 0.** The paste overshot to z ≈ 20, and the generator owns z ≥ 0 — it overwrites
   that sliver every boot. The overlap is harmless (better than a gap) but anything built there is lost.
2. **The bay does not reach the river.** Bay water ends at **z ≈ −106**; the channel starts at **z 0**.
   Between them is ~106 studs of solid land (measured: z −60 has 4,955 solid voxels and zero water).
   **That is the carve** — widen the bay and cut it north to z 0, centred on X 0, ~150 wide to match.

## ✅ The river mouth — carved by Claude (procedural, not hand-sculpted)

Three passes, each computed and verified by read-back + screenshot per the `roblox-terrain` discipline.

1. **Straight channel** — bay → junction, valley taper instead of a slot canyon (the land climbs from
   Y 38 at z −100 to Y 74–102 at z 0, so a plain trench would have dropped to a 10-stud bank at the seam).
2. **Meander** — snaking centreline, easing dead-straight over the last 70 studs so the junction stays
   locked. Measured centre tracks the design within a few studs: `+10 → +42 → +38 → +2 → −34 → −36 →
   −8 → 0`, width steady 144–152.
3. **Deepen** — the bay kept the lobby's shallow harbour floor (bed Y 0, only 12 deep) and the bed
   showed through the water. Now **uniform 20-stud depth** (bed −8, surface 12) across the whole body,
   matching the generated river.

### ⚠️ A wrong call I made, corrected

I told the user a real meander was impossible because "removed terrain can't be restored". **That was
wrong.** I can't recover the *original* voxels, but a meander doesn't need them — where the channel
moves away you **fill new bank**, which is just building a riverbank. The corrected pass filled
**18,017 voxels** and carved 2,405. If a future pass needs the true original terrain back, the lobby
place is still untouched and the region can be re-copied.

### Verified in a live server

Unbroken navigable water **z −300 → 900, zero gaps**, surface Y 12 throughout, and the handoff at z 0
is invisible: 152 studs sculpted → **148 generated**, then walking off seeded (centre −128 by z 500).

### Boat berth (the user's X)

Southern lobe measured berth-able at **(−140, −280)**, **(−120, −260)** and **(−100, −240)** —
236–278 water voxels each, 20 studs deep. Enough for the 32-stud boat. Wiring `StagingServer` to it is
the next job, not this one.

## 🔴 INCIDENT — I damaged the hand-sculpted hillside (2026-08-02)

**What happened.** The valley-shaping pass shaped terrain out to **225 studs** either side of the
channel centreline, blending toward a reference height sampled at 300. Where the hillside rose steeply
*inside* that band but the reference column beyond it was lower, the profile treated the mountain as
terrain to cut down to the blend surface.

**Damage measured:** a **~400-stud-wide plateau flattened to exactly Y 20** (`BANK_MIN`) across the
valley — at z −180, everything from x −180 to +220 reads 16–20 where the hillside used to rise — plus
**22 floating rock columns** at X 244…292, Z −208…−136 sheared off at the cut edge.

**Root cause:** the river needs ~40 studs of bank. I gave it 225. A "blend back to the surroundings"
profile is not a bound — it says nothing about what lies *between* the channel and the reference column.

**Recovery:** the user is restoring the hillside by hand. The lobby place is untouched, so the original
terrain remains recoverable from there if needed.

**Prevention (done):** `roblox-terrain` §1b now requires every terrain edit to declare a hard extent and
enforce it in code — `MAX_DX` and, critically, **`MAX_Y`**. The river never needs to modify anything
above ~Y 25; a `MAX_Y = 40` guard alone would have made this impossible.

**Sequencing note:** a hillside restore that re-pastes from the lobby will also wipe the river carve —
the river must be re-cut *after* the restore, not before.

### Also corrected: my navigability test was too weak

The earlier "unbroken navigable water z −300 → 900, zero gaps" check only asked whether *any* water
existed in each z-slice. **A slice with water either side of a land bar passes that test while being
impassable.** Re-tested properly with a flood fill from the dock: 2,750 connected water columns,
furthest Z reached **22** — genuinely navigable. Right answer, but the original test did not prove it.

## Steps

1. ✅ **`workspace.LOBBY_TERRAIN_EXPORT`** created in the LOBBY place — a `TerrainRegion`, additive and
   reversible (no lobby terrain was modified).
2. ⏳ **User:** select it in the LOBBY Explorer → **Ctrl+C** → switch to the GAME Studio → **Ctrl+V**.
3. **Claude:** `Terrain:PasteRegion` at `(−702, −22, −922)`, then delete the helper instance.
4. **Claude:** verify water lands on Y 12 and the zone occupies Z −900…0.
5. **User:** remove the airstrip; widen the bay and carve the channel north to Z 0.
6. **Claude:** add the seed-lock band + protected ranges (Part 3), stop `Terrain:Clear()` wiping it.
7. **Both:** generate the corridor and check the seam in Play.

> ⚠️ **Step 6 must land before serious sculpting.** Until the lock exists the channel position at the
> junction still moves with the seed, and until `Terrain:Clear()` is gone every Play test wipes the
> pasted terrain.

# Part 4 — Original open questions (1–3 now answered above)

1. **Size of the two end zones.** The sketch bulbs read ~2–3× the corridor width. For reference the
   lobby clearing is roughly 1200×1200 studs — a known-good size to sculpt and populate.
2. **Straight or fixed-curve approach?** Locking the channel dead straight is simplest. A gentle *fixed*
   curve also works — it only has to be seed-independent, not straight.
3. **Does the END need navigable water?** Do players drive in and moor, or does the run stop at a finish
   line and put them ashore? Decides whether the end zone needs a real channel or just a shore.
4. **Cleanup scope.** Delete all the leftover corridor terrain and start clean, or keep some as a
   sculpting reference?
5. **Ordering.** The lock band must exist **before** you sculpt — sculpting first and adding the lock
   afterwards would move the channel out from under the work.

## Out of scope here

Populating the zones with props/objects (next job), audio, and the HUD restyle.

## Checklist

- [x] Game logic + current terrain state read
- [ ] Design decisions agreed (Part 4)
- [ ] `RiverData` lock band + protected ranges
- [ ] `RiverBootstrap` targeted clear / skip protected chunks
- [ ] Corridor cleanup
- [ ] Editor base generated for both end zones
- [ ] Hand-sculpt (user)
- [ ] Seam verified in Play, both ends
- [ ] Final summary + changelog
