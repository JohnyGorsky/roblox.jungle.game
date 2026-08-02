# Final Summary — Job #071

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — the START zone exists, joins the generated river seamlessly, and is
navigable. **Two real mistakes were made on the way; both are documented below and both produced
permanent guards in the `roblox-terrain` skill.**

## What was built

### 1. The START zone — the lobby terrain, relocated

The lobby's hand-sculpted terrain (976 × 900 studs) was copied via a `TerrainRegion` and pasted into
the GAME place at cell corner `(−175, −6, −230)`.

| Axis | Offset | Why |
|---|---|---|
| X | −300 | harbour centre → the river centreline |
| **Y** | **+16** | water surface **−6 → exactly 12** (`WATER_Y`) |
| Z | −300 | lobby Z −598…302 → game **−898…~20**, junction at Z 0 |

`+16` not `+18`: `PasteRegion` corners are **cells**, so offsets are multiples of 4, and the offset must
be derived **surface-to-surface** (top water voxel spans −8…−4 → 12) rather than centre-to-level.

### 2. Code guards so generation and sculpture coexist

| File | Change |
|---|---|
| `RiverData` | `START_ZONE_Z_END` / `END_ZONE_Z_START` / `LOCK_CENTER_X` / `LOCK_WIDTH_*` / `LOCK_BLEND` + `lockFactor()`; `centerlineX` and `widthAt` blend seeded → locked; forks suppressed in a lock band |
| `RiverGenerator.chunkRegion` | **clamps** Z to the zone boundaries — clamping not skipping, because 18000/256 = 70.3 and skipping chunk 70 would leave an 80-stud hole |
| `RiverBootstrap` | **`Workspace.Terrain:Clear()` removed**, with a comment on why it must never return |

**Seed-lock verified across 5 seeds** (2026, 7, 999999, 31337, 555): centreline spread at z 0 and
z 18000 is **0.00**, width locked to 150 / 300, blending to fully seeded by ~z 1600. Without this the
hand-sculpt would have aligned for exactly one seed.

### 3. The river mouth — carved procedurally

Bay → junction: meandering channel (measured centre tracks the design within a few studs), widened to
**176–208 studs**, uniform **20-stud depth**, banks clear of the waterline, tapering to the locked
**148** at z 0.

### 4. Water levelled

All **3,622 water columns at surface exactly 12**, zero partial-occupancy seams.

## Verification (final, in a live server)

- [x] **Sculpted zone survives a server boot** — the `Terrain:Clear()` removal proven; 13,067 occupied
      voxels across the sampled start-zone slices (~62% fill)
- [x] **Seam invisible**: z −20 sculpted 160 wide → z 0 generated **148**, same water level, then
      walking off seeded (centre −128 by z 500)
- [x] **Navigable dock → river**: flood fill reaches **8,046 connected water columns to z 498**;
      narrowest point on the route **52 studs** against a 14-stud boat beam
- [x] Water level uniform at 12; no seams

> The navigability test was **rewritten mid-job**. The original checked "is there any water in this
> z-slice", which a slice with water either side of a land bar passes while being impassable. Replaced
> with a flood fill. Right answer originally, wrong evidence.

## 🔴 Mistakes made, and what came of them

### A. I destroyed part of the hand-sculpted hillside

A valley-shaping pass shaped terrain out to **225 studs** either side of the channel, blending to a
reference height sampled at 300. Where the hillside rose steeply *inside* that band but the reference
beyond it was lower, the profile cut the mountain down to the blend surface — **flattening a ~400-stud
plateau to Y 20** and leaving 22 floating rock columns. The river needed ~40 studs of bank.

The user restored the hillside by hand.

**Guard added** (`roblox-terrain` §1b): every terrain edit must declare a hard extent and enforce it in
code — `MAX_DX` and, critically, **`MAX_Y`**. On the corrected pass the guard **skipped 178 columns**
that stood above Y 40; those are precisely the ones the old code flattened.

### B. My probe regions were clipping the measurements

A `ReadVoxels` region with a Y ceiling of 40 reports every taller column **as 40**. A bank was therefore
diagnosed as "a 28-stud cliff at 40" and a grading pass written against it — the real ground was
**76–104**. **371 columns were graded on that bad reading** before the error was caught.

**Guards added** (§2): size probe regions to the terrain's true range; treat "many columns at exactly my
ceiling" as the tell; don't invent pass/fail thresholds (an arbitrary ">20,000 voxels = intact" test
reported a false failure in this very job).

### C. The legacy voxel API silently refused to repair water

Sculpting left voxels holding **partial mud AND water simultaneously**. `ReadVoxels` exposes one
material per voxel, so it reported `Mud 0.5` and hid the water; two read-modify-write repairs each
reported success and **changed nothing**. `ReadVoxelChannels`/`WriteVoxelChannels` fixed it in one pass
(508 solid dissolved, 451 liquid set full).

**Guard added** (§4): if terrain and water are tangled in the same voxels, use channels immediately —
and **verify in a separate call**, because re-reading right after a write in the same script returned
stale data and would have let a no-op be reported as a fix.

## Files changed

| File | Change |
|---|---|
| `sync/ReplicatedStorage/River/RiverData.luau` | editor-zone constants, `lockFactor`, locked centreline/width, fork suppression |
| `sync/ServerScriptService/River/RiverGenerator.luau` | `chunkRegion` clamps to the zone boundaries |
| `sync/ServerScriptService/River/RiverBootstrap.server.luau` | removed the boot-time `Terrain:Clear()` |
| `.claude/skills/roblox-terrain/SKILL.md` *(workspace repo)* | rewritten 92 → ~230 lines; §1b bounding rule, probe-clipping, fresh-call verification, channel API |
| `.claude/skills/roblox-terrain/reference/terrain-api.md` *(workspace repo)* | verified limits/signatures from the official docs |
| GAME place terrain + `SpawnBase` | place content — **saved by the user** |

## Outstanding

| Item | Owner |
|---|---|
| **East bank is a 64-stud cliff** (water at 12, ground 76–104). Either pull the water back or deliberately cut a shoreline — **undecided, deliberately not actioned** | decision |
| The **371 graded columns** from mistake B were never reviewed or reverted | decision |
| A land strip the user circled was **never located** — I could not match the screenshot to coordinates and stopped guessing. Offer stands to read it from the Studio selection | user |
| **END zone** (extraction/rewards at z 18000) not started — the lock band already exists for it | next job |
| Wiring `StagingServer` to the new dock/berth | next job |
