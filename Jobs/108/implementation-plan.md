# Implementation Plan — Job #108

**Project**: `roblox.jungle`
**Created**: 2026-08-23 20:39:19
**Status**: Planning (awaiting go-ahead)

## Analysis

MEASURED FACTS (probed in Studio, Edit datamodel, ServerStorage.AssetLibrary.Structures):
- BahayKubo1 19.8 x 16.2 x 27.0, 22 parts. Floor sits 3.5 studs above the model base. ONE walk-through doorway, model-local bearing 214-232 deg (centre ~223, where +X = 0 deg and bearing increases toward +Z). Headroom above floor 11.1.
- BahayKubo2 24.7 x 16.1 x 21.8, 18 parts. Floor 3.5 above base. Doorway at 204-222 deg (centre ~213); a second narrow gap at 18-26 is a window-height opening on the far side. Headroom 9.2. Currently UNUSED anywhere in the game.
- BahayKubo5 29.6 x 22.4 x 34.0, 13 parts. Floor 4.6 above base. Open-sided - 27 of 36 bearings clear. Already the camp default hut.
Probe method: clone into Workspace, raycast down from inside for the floor, then sweep 180 horizontal rays at floor+1.0/+2.5/+4.5 and keep only bearings clear at ALL THREE heights (a doorway, not a window). Re-run it if a model is ever swapped.
CONSEQUENCE: placing these models is NOT enough to make them enterable. A 3.5-stud floor is above the Humanoid auto-step (~2) and needs a jump. Each hut needs a step/ramp at its OWN doorway, so the door bearing is load-bearing data, not decoration.

BASIN GEOMETRY (ExcursionServer): BASIN_SIZE 400, basinCenterX = waterEdge + side*200. Near camp at inland 120, deep camp at inland 300 with +40 Z offset. Camp fence radius 70-76 (CampLayout RADIUS_MIN/MAX) and each camp re-clears a 160-stud square FOOT. Clearing ring trees sit 24-46 studs in from the basin edge; interior scatter (22 trees) stays inside ringZone 70. Path lane PATH_HALF 18 from shore to deep camp. Trading post at dock.z-24, 90 studs inland.
FREE AREA for outlying huts, computed against those: a 250x250 box (basin centre +/-125, inside the tree ring) minus two ~100-stud camp exclusion discs minus the path lane leaves roughly 25000 sq studs - enough for 6-10 huts at ~48-stud separation, but tight enough that rejection sampling must be logged, not assumed.

BUG FOUND IN PASSING: CampLayout.RAW lists BahayKubo1 as 30x34 (it is 19.8x27.0) and BahayKubo7 as 40x40 (it is 40.2x50.2). The Kubo1 entry over-estimates its half-diagonal by ~5 studs, which costs camp buildings via rejection sampling - directly relevant to 'each camp feels empty'.

DECISIONS (user, via wizard): scatter across the WHOLE basin outside both camp rings; 6-10 huts per landing site; genuinely enterable WITH loot inside; models = Kubo1 + Kubo2 + Kubo5/Tent; loot = SALVAGE STASHES ONLY (instant ~25-40 salvage, no carry) so the boat's fuel/metal/ammo cargo economy is untouched; even random scatter.
OUT OF SCOPE (noted, not done): making the camps' OWN huts enterable - same helper would do it, but it changes camp collision and is a separate call. Goes to Planned/.

## Implementation steps

1. Move the model footprint table out of CampLayout into CampDefs.FOOTPRINT as the single source, with the three MEASURED corrections (BahayKubo1 19.8x27.0, BahayKubo2 24.7x21.8, BahayKubo7 40.2x50.2). CampLayout.halfDiagonal reads it. Expect camps to fit slightly more buildings - that is the point.
2. Add CampDefs.VILLAGE: the outlying-hut content table - weighted model list (Kubo1, Kubo2, Kubo5, Tent), count range 6-10, per-model DOOR bearing and floor rise as measured above, the entry-step spec, and the stash spec (model, chance, salvage range). CampDefs stays the one place a landing site's contents are listed.
3. New module sync/ServerScriptService/World/VillageLayout.luau: seeded, deterministic placement of the outlying huts. Takes basin centre/size, waterEdge/side, both camp positions with their radii, the path segment, the trading-post position and a seed; returns world x/z + model + yaw + door direction. Enforces: inside the tree ring, off the water, clear of both camp fences by fence-radius + the model's own half-diagonal, off the path lane, clear of the post, and mutually separated by the SUM of the two models' half-diagonals (the same rule CampLayout learned the hard way - never a fraction of it). Yaw is chosen so the DOOR faces the walking route jittered +/-70 deg, which keeps the random-looking rotations from the sketch while guaranteeing no door faces the jungle wall.
4. Footprint-validate every candidate slot before accepting it: probe ground at the footprint corners and centre, reject a slot whose ground spread exceeds ~2.5 studs. One raycast cannot validate a 20-36 stud building, and the basin carve leaves ~2.5 percent stumps.
5. ExcursionServer: compute the village slots right after the camp positions are known and BEFORE the interior tree scatter, then have the tree loop skip anything within a hut footprint - otherwise a tree that was planted first ends up inside a hut placed later.
6. ExcursionServer: build the huts AFTER both camps (so the camp FOOT terrain fills and settleTerrain have already run). For each hut: prop() with collide=true, then build the entry step at the door, then the interior stash. Log placed-vs-requested per site so a silent shortfall is visible instead of reading as 'the scatter is sparse'.
7. Entry step: a small wooden platform/step pair in front of the measured doorway, sized from that model's floor rise, so the doorway is a walk-in rather than a jump. Verify by walking in, not by looking at it.
8. Salvage stash: a Barrel seated on the HUT FLOOR (ground + floor rise), CanCollide off so it cannot trap a player in a small interior, with a Search prompt. New Kind='Salvage' branch in pickupLoot that awards salvage and destroys the stash - no carry, no Busy, no cargo.
9. Verify in PLAY at a real landing site: count huts placed, walk into at least one Kubo1 and one Kubo2 through the door, confirm the step is walkable, loot a stash and watch the Salvage attribute rise. Failure looks like: fewer than 6 huts, a hut on a stump, a door facing a wall, a step you have to jump, or a stash that is unreachable inside.
10. Update ASSETS.md (BahayKubo2 moves from 'variety - unused' to in-use) and the workspace model registry; add the deferred camp-hut enterability item to Planned/.

## Independent review (GROUND-RULES 8)

Every job gets at least one agent, handed the symptom and the repo but NOT my hypothesis - the whole value
is that it is not anchored to my theory. A second agent is mandatory after one failed fix.

- [ ] Agent run, without being told my theory
- **What it said to check first**: _TODO_
- **What came of it**: _TODO_

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification - MANDATORY GATES (GROUND-RULES 7)

None of these may be ticked from an Edit session. Edit does not run LocalScripts and has nothing created at
runtime, so it cannot show a whole class of bug.

- [ ] **Reproduced in PLAY**, at the player's camera angle, BEFORE attempting a fix
- [ ] If this was "works in X, broken in Y": environments diffed FIRST - client scripts and their VFX,
      runtime-created instances, tick-driven systems, place settings
- [ ] Every check below says what a FAILURE would have looked like
- [ ] Before/after from the SAME camera, and the "before" is kept
- [ ] No world fact asserted from a constant - measured instead
- [ ] The fix accounts for the REPORTED symptom, not just for real bugs found on the way

### Checks

- [ ] _TODO: what is checked, and what failure would look like_
