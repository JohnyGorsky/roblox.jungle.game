# Planned: River journey overhaul (make the river interesting)

**Project:** `roblox.jungle` — user vision, 2026-07-19. Build mechanics/greybox now, art later. Expands the
existing (already-working) seeded generator into a varied, paced *journey*. The generator, foliage, and
excursion/camp systems already exist (Jobs 005, 011, 012) — this is enrichment, not from scratch.

## User feedback driving this
1. Turns feel **straight & predictable** — want more, more-varied bends.
2. **Off-limits areas** (where you shouldn't walk) = **dense trees + frequent enemy spawns** (channel the player).
3. Disembark → a **clear tree-free walk path** to the camp/objective; camps have a **predefined, NON-respawning**
   monster count that **escalates** with each successive camp (not infinite respawns).
4. River **splits around small islands, then merges** — add braided set-pieces.
5. **Stops must be paced** (leg time feels challenging); add more stops so **stopping is a real choice**
   (skip to save time vs stop to refuel/loot).
6. Levers to make zone-dependent (confirmed): **width, meander/turns, obstacle density, current speed, + small islands.**

## Proposed per-zone profile (4 zones over END_DISTANCE=18000; smooth blends at borders so no seams)
| Zone | Distance | Width | Turns (meander) | Obstacles | Current | Character |
|------|----------|-------|-----------------|-----------|---------|-----------|
| Headwaters   | 0–4500      | ~150 | gentle, few       | sparse   | 1.0x | calm ease-in |
| Croc Country | 4500–9000   | ~210 | big lazy bends    | moderate | 1.0x | wide, meandering |
| The Rapids   | 9000–13500  | ~95  | frequent SHARP    | dense    | 1.5x | tight & fast — the peak |
| Lost Delta   | 13500–18000 | ~300 | braided           | moderate | 0.8x | splits around islands → merge → finish |

(Numbers are a starting point; tune in-engine.)

## Jobs (sequential — foundation → richness)
1. **[Job 047 — done]** Zone-driven river shape + turn variety — `RiverData` `ZONE_PROFILE` (width/turn/
   obstacle-density interpolated by distance) + 3rd meander octave scaled by per-zone turniness. Rapids
   narrows/twists/dense, Delta wide, Headwaters calm. Verified continuous + drivable.
2. **Per-zone current** — `RiverData.currentMulAt(z)` + one line in `BoatServer` (`* currentMulAt`). Fast
   Rapids, slow Delta. Boat-physics testing.
3. **Forks + small islands** — `RiverData` (a second offset centerline + island mask) + `RiverGenerator`
   (carve two channels, fill the island) + culling both branches; boat just drives whichever side. Concentrated
   in the Delta, occasional set-pieces elsewhere. Heaviest piece.
4. **Off-path = dense & dangerous** — `FoliageServer` (thicken trees on steep/off-path ground, keep intended
   routes clearer) + `EnemyServer` (higher spawn frequency in dense off-path bands) so wandering off is punished.
5. **Excursion/camp rework** — `ExcursionServer`: a clear tree-free **path** from the disembark point to the
   camp; **predefined, non-respawning** rosters per camp that **escalate per successive landing** (track a
   per-run camp counter), replacing/curbing any respawn.
6. **Pacing & optional stops** — `DockServer` + `RiverData` (dock spacing) + fuel economy: compute leg times so
   distance feels challenging, add more stops, and tune fuel so **skipping a stop is a real risk/reward** (can't
   skip them all). Some stops quick-refuel, some full landing raids.

## Notes
- All greybox; the art pass (real trees, rock walls, island props, water FX) swaps visuals later.
- Daily-seed mode for fair leaderboards stays deferred to P11 live-ops.
- Ties together: zones (Job 035), obstacles (036), foliage/excursions (011/012), boat (003), fuel economy.
