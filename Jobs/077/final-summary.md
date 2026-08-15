# Job #077 — Final summary

**Dock camps + docks on real assets.** Every visible object at a landing site is now a model from
`ServerStorage.AssetLibrary`; `block()` survives only for invisible trigger/anchor parts.

## What shipped

**Three new modules** (`sync/ServerScriptService/World/`):

- **`CampDefs.luau`** — the dressing table. Which model plays which role, per-model corrective scale,
  layout slots, the clearing ring, ground-paint weights, VFX/light budgets, audio ids, tags. The server
  script owns no content decisions, mirroring the `FoliageDefs`/`FoliageServer` contract.
- **`Campfire.luau`** — built, not sourced (every Store result was the same spam-uploaded "realistic"
  campfire, the wrong register for our look). `RockA/B/C` ring + crossed `LogMossy` + Fire/Smoke/embers/
  PointLight/crackle on one anchor part.
- **`CampAmbience.luau`** — fireflies (night) / dust motes (day), three warm practicals, and two shared
  `CollectionService`-driven tasks (phase gating, fire flicker) that prune themselves as camps are culled.

**Rewritten:** `DockServer` (real `Dock` pier; `Deck` kept as an invisible anchor so `TieSpot`, the rope
and the prompt keep byte-identical geometry; deck height measured at runtime; sub-waterline pilings
non-colliding so the boat can nose in), and the camp half of `ExcursionServer`.

**Swaps:** huts → `BahayKubo5`/`BahayKubo1` · 2 grey blocks → `Tent` (scaled 0.42) · loot → one hero
`CrateWood` + `Barrel`s · kind-crates → `AmmoBox` · 8-block stall → `BahayKubo7` + a physical
`SurfaceGui` sign (the old `AlwaysOnTop` billboard rendered through terrain) · Neon cube → the Meshy
`GoldNugget` · carried crate → a scaled `Barrel` · plank deck → the `Dock` model · `SandbagWall` ×3 as
cover · `RangerTower` at each landing.

## Verified live (measured, not eyeballed)

| Check | Result |
|---|---|
| Seating | `ok=124  FLOATING=0  BURIED=0` |
| River unaffected | `0 / 1691` channel samples — identical to two no-camp control stretches |
| Route dock → camps | ground 16.8→18.0, worst step **0.8** studs — walkable, no hill between |
| Stumps in camp footprints | 0 |
| Wiring | `LootPrompt ×6`, `NuggetPrompt ×1`, `ShopPrompt ×1`; crate attrs intact |
| Night | 8 practicals switch on at dusk, fireflies on / motes off, fire flickers 1.93–3.11 around base 2.6 |
| Cost | 880 BaseParts per landing site |
| Analyzer | clean |

## The lesson

**One sample used to validate a large footprint** caused nearly every bug in this job: one raycast for a
43-stud tent, one bank sample for a 400-stud carve, for a 218-stud canopy tile, for walls 215 studs
upstream, for paint discs, and for a trading post 24 studs off the dock. Models here are 20–218 studs
across and the river meanders; a point test cannot validate them.

Fixes now shared: `FoliageDefs.groundClearFraction` (tests the *footing*, not the bounding box — canopy
over water is wanted, it's the alley), `bankForSlice` (most-inland bank across a span + margin), sliced
carve/paint, and a stump-aware `groundAt` that asks the surrounding basin when the point itself is
unusable.

Three Roblox facts that cost the most time, all now recorded in code comments:

1. **A terrain write is not raycast-readable in the same script** — produced `groundAt=22.0` on ground
   measuring 17.0. Fixed with a two-frame `settleTerrain()` after every write.
2. **`FillBlock`/`FillCylinder` CREATE ground, they do not only recolour it** — the "repaint" scatter was
   building new land out over the river.
3. **`carve` is imperfect** (~2.5% of columns survive as stumps), so camps re-clear their own footprint.
4. **Camps were being built ahead of the streamed terrain** — `RiverBootstrap` keeps ~1800 studs
   generated; sites built up to 1400 ahead and `ForceFirstCamp` ~1900. `terrainReadyAt()` now refuses to
   build until terrain exists, and does not mark the site built so the loop retries.

## Deliberate trade-offs

- **Crate tint dropped.** The greybox tinted crates per resource; real barrels can't carry that without
  the neon-prop look §12 forbids. What's inside is read off the `LootPrompt` text on approach. If it
  matters in play, the fix is a stencil or icon — not re-tinting the barrel.
- **The ring is individual trees, not `JungleTreesPack`.** Measured both ways: the 218-stud pack either
  buried 27–45 studs of itself in the basin's rock wall or landed on the deep camp.
- **The trading post gets no levelling pad.** Tried twice; both put solid ground in the channel (32 then
  77 studs). It stands on the basin carve instead.

## Not changed — needs a decision (Job #076 territory)

**The shelf artifact.** `roblox-terrain` §4: no land may sit between `WATER_Y` and `WATER_Y + 8` or it
renders as thin hole-riddled sheets. `RiverGenerator` ramps the bank from *exactly* the waterline, and
`FoliageServer.MIN_GROUND_Y_ABOVE_WATER = 1` lets foliage plant there. Raising it to 8 would delete the
palm alley (`inland = {1,7}`); changing `BANK_LIP` alters all 18,000 studs of river.

Also unchanged: `cullChunk` clears terrain ~500 studs behind the boat while a landing site survives to
`CULL_BEHIND` (1200), so a passed camp can briefly stand on nothing.

## Still outstanding

Full loop driven by hand (tie → ashore → raid → haul → deposit → untie); smoke column judged **from the
boat** at approach distance; Device Emulator with #076 foliage live.
