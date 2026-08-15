# Job #077 — status (updated 2026-08-15)

Generated and playtested end-to-end in the GAME place. **All three checks the user asked for pass.**
Nothing is committed (never-commit rule); everything is in the working tree.

## Verification — measured live, not eyeballed

Landing site at z=1600, built by the normal streaming path (boat driven within `CAMP_AHEAD`):

| Check | Result |
|---|---|
| **Nothing floats / nothing buried** | `ok=124  FLOATING=0  BURIED=0` over every top-level object |
| **River unaffected** | `0 / 1691` channel samples have solid ground — **identical to two control stretches with no camp** |
| **No hill between dock and camps** | ground 16.8→18.0 over the whole route (1.2 studs), worst step **0.8** → WALKABLE |
| Stumps in camp/post footprints | 0 |
| Gameplay wiring | `LootPrompt x6`, `NuggetPrompt x1`, `ShopPrompt x1`; crate attrs `Gasoline, Gasoline, Metal, Ammo, Weapon, Ammo` |
| Ambience | lights 8, VFX 10, sounds 2 (per site) |
| Cost | **880 BaseParts** per landing site |
| Analyzer | `tools/luau-analyze.sh` clean |

> `ShopSign` reports as "+4.7 floating" in a naive sweep and is a **false positive** — its two `Post`s
> measure bottom = 17.0 against ground 17.0, and the board is *meant* to hang 6 studs up them.

## The root cause behind almost all of it

**One sample used to validate a large footprint.** Every failure in this job was a variant of it:

| Symptom | The single sample that was wrong |
|---|---|
| Canopy tiles in the river | one bank sample for a 218-stud `JungleTreesPack` |
| "Land is outside" | one bank sample for a 400×400 square carve |
| Rock walls in the channel | the dock's bank used for walls 215 studs up/downstream |
| Grass/dirt in the channel | paint discs centred without regard to their own radius |
| Trading post + sign floating | the dock's bank used for a post 24 studs upstream |
| Tent/Barrel/AmmoBox floating | one raycast that landed on a leftover terrain stump |

Fixes: `FoliageDefs.groundClearFraction` (footprint/footing test), `bankForSlice` (most-inland bank
across a span, + margin), sliced carve/paint, and a stump-aware `groundAt` that asks the surrounding
basin when the point itself is unusable.

### Two Roblox gotchas that cost the most time

1. **A terrain write is not readable in the same script.** `roblox-terrain` §2 warns about it; here it
   produced `groundAt=22.0` on ground that measures 17.0 a moment later, floating the trading post.
   Fixed with `settleTerrain()` (two frames) after every terrain write, before anything raycasts it.
2. **`FillCylinder`/`FillBlock` CREATE ground, they do not only recolour it.** The "repaint" discs in
   `paintBasin` were building new land out over the river — the last 14 channel intrusions, all
   `Grass`/`Ground` material.
3. **`carve` is imperfect** — ~2.5% of columns survive as stumps. Camps now re-clear their own 130-stud
   footprint, which is cheaper than trying to make the basin-wide carve perfect.

## Also fixed earlier in the job

- **`GoldNugget` never spawned** — it is a bare `MeshPart`, and the library scan + `prop()` were
  Model-only, so it returned nil *and still burned a capped nugget slot*.
- **`Tent` at 43×34 studs** read as a giant tarp bigger than the huts → `CampDefs.SCALE` (0.42).
- **Camps built before terrain streamed.** `RiverBootstrap` keeps ~1800 studs generated ahead and culls
  the rest; sites were built up to 1400 ahead and `ForceFirstCamp` ~1900 ahead. Fixed with
  `terrainReadyAt()`, which refuses to build (and does not mark `built[]`) until terrain exists.

## Known limitation, NOT changed — needs a decision

**The shelf artifact.** `roblox-terrain` §4: no land surface may sit between `WATER_Y` and
`WATER_Y + 8`, or it renders as thin hole-riddled sheets. `RiverGenerator` ramps the bank from *exactly*
the waterline (`lip = min(edge*0.6, BANK_LIP)`), so the first ~13 studs of every bank are in that band,
and `FoliageServer.MIN_GROUND_Y_ABOVE_WATER = 1` lets foliage plant there. This is the likeliest cause
of anything still looking like it floats at the shoreline.

Not changed because raising `MIN_GROUND_Y_ABOVE_WATER` to 8 would **delete the palm alley** (its band is
`inland = {1,7}`), and changing `BANK_LIP` alters all 18,000 studs of river. **Job #076 decision.**

Also unchanged: `cullChunk` clears terrain ~500 studs behind the boat while a landing site survives to
`CULL_BEHIND` (1200), so a passed camp can briefly stand on nothing. Players have left by then.

## Still outstanding

- Full loop by hand: ride → tie → ashore → raid → haul → deposit → untie (systems verified individually,
  attributes and prompts confirmed intact, but not driven end-to-end by a player).
- Night pass (`NightLight` switch at 17.5 h) and the smoke column read **from the boat**.
- Device Emulator with #076 foliage live.
- Bookkeeping: `ASSETS.md` §3.5 statuses, `Planned/camp-night-practicals.md`, `final-summary.md`,
  `changelog.md`.
