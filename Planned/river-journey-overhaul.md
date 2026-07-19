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
2. **[Job 048 — done]** Per-zone current — `BoatServer` current force `* RiverData.currentMulAt(z)`. Rapids
   ×1.5 (18000), Delta ×0.8 (9600), others ×1.0. Verified end-to-end.
3. **[Job 050 — done]** Forks + small islands — `RiverData.branchesAt`/`forkOffsetAt` (split→island→merge in
   wide zones) + `RiverGenerator` two-branch carve with a low island between; hooks/docks suppressed in forks.
   Verified: Delta channel splits around an island into two branches.
4. **[Job 051 — done]** Off-path = dense & dangerous — `FoliageServer` thick inland-biased fork-aware bank
   forest (clearing at landings) + `EnemyServer` higher land caps (3/7) & faster spawns emerging from the
   treeline. River = safe corridor, banks = hostile jungle.
5. **[Job 053 — done]** Excursion/camp rework — `ExcursionServer`: tree-free walking lane (0 trees within 18
   studs) + dirt `CampPath` from shore to camps; escalating non-respawning rosters (tier=ceil(dockIndex/2):
   near=tier, deep=tier+1, cap 6). Verified.
6. **[Job 054 — done]** Pacing & optional stops — `DOCK_SPACING` 1600 (landings every 3200), near camp gives 2
   gasoline (funds skipping one stop, not two), and a **NEXT FUEL** HUD readout (distance + green/red reachable)
   so the stop-or-push decision is informed. Verified.

**✅ RIVER JOURNEY OVERHAUL COMPLETE (all 6 items).** Remaining tuning is playtest-driven; the art pass (P9)
swaps all greybox.

## Notes
- All greybox; the art pass (real trees, rock walls, island props, water FX) swaps visuals later.
- Daily-seed mode for fair leaderboards stays deferred to P11 live-ops.
- Ties together: zones (Job 035), obstacles (036), foliage/excursions (011/012), boat (003), fuel economy.
