# Final Summary — Job #108

**Project**: `roblox.jungle`
**Completed**: 2026-08-23 20:52:22
**Status**: ✅ Completed

## What was implemented

A landing site now builds 6-10 outlying, ENTERABLE huts scattered across the basin around its two camps.

WHAT SHIPPED
- New sync/ServerScriptService/World/VillageLayout.luau. Seeded, deterministic scatter of outlying huts across the basin OUTSIDE both camp fences. Rejects any slot that is inside a camp ring, on the walking lane, on the trading post, on the shore, in the clearing-ring trees, overlapping another hut (checked against the SUM of both half-diagonals), or on ground that is not flat across the hut FOOTPRINT.
- CampDefs.VILLAGE - the content table: weighted model mix (BahayKubo1 x4, BahayKubo2 x4, BahayKubo5 x2, Tent x1), count 6-10, per-model measured door bearing + floor rise, the tread spec, the stash spec, and every placement margin.
- CampDefs.FOOTPRINT + CampDefs.halfDiagonal - one shared footprint table. CampLayout.RAW is gone and CampLayout reads this instead.
- ExcursionServer: rawGroundAt (a probe that does NOT hide stumps the way groundAt deliberately does), buildVillageHut (place, build the entry treads, seat a stash on the hut floor), a Kind=Salvage branch in pickupLoot, and the wiring in buildLandingSite.

THE THING THAT WAS NOT OBVIOUS
Placing these models does NOT make them enterable. Measured in Studio: every Bahay Kubo is a stilt house whose interior floor sits 3.5-4.6 studs above its own base, which is above the ~2-stud ledge a Humanoid climbs for free, and BahayKubo1/BahayKubo2 have exactly ONE walk-through doorway each. So the job needed two measurements per model - the floor rise and the door bearing - and the yaw is chosen FROM THE DOOR OUTWARD (door aimed at the walking route, then jittered +/-70 deg) so the scattered look survives without ever aiming the only way in at the jungle wall. Probe method is recorded in the implementation plan; re-run it if a model is swapped.

BUG FIXED IN PASSING
CampLayout listed BahayKubo1 at 30x34; it is 19.8x27.0. Since camp buildings are placed by rejection sampling against the SUM of two clearances, ~5 studs of phantom clearance per hut cost camp buildings - part of the same empty-camps report this job came from. BahayKubo7 was listed 40x40 against a real 40.2x50.2 (unused since #107, but a trap). Both corrected in CampDefs.FOOTPRINT, and ASSETS.md + the workspace model registry now carry the measured sizes, the door bearings and the stilt-floor warning.

ECONOMY - DELIBERATELY THE SMALL LEVER
Hut stashes grant SALVAGE only (25-40, instant, no carry, no Busy, no cargo). A landing site is tuned against exactly four carryable resource crates; filling 6-10 new huts with Gasoline/Metal would have tripled the haul per site and added that many one-at-a-time trips to the boat. Chance 0.75, so an empty hut is what makes a stocked one worth the walk.

VERIFIED IN PLAY, NOT IN EDIT (landing site 1, live run)
- 7 of 6-10 huts placed. All 7 seated at exactly -0.30 float (the intended sink) - none floating, none buried.
- 2 treads on every hut, tops at 1.75 and 3.50 above base - each rise inside the free step-up.
- Doorway clear inward and approach clear on all 7 (raycast at body height).
- WALKED IN: Humanoid:Move straight at the door with Jump never set took the character from ground (feet ~17.0) onto the hut floor (feet ~20.2). Screenshot shows the player standing inside with the steps below.
- Looted a stash: Salvage 0 -> 35, stash destroyed, Busy=false and Carrying=nil (no carry path taken).
- Camps still fit 3 buildings each after the footprint correction (BahayKubo1 x2, BahayKubo5 x2, Tent x2 across two camps).
- Cost: 184 BaseParts for 7 huts, against 128 for the single RangerTower already at every site.
- Analyzer clean (luau-lsp with Roblox definitions) on all four Luau files; the analyzer was confirmed able to fail on a deliberate control error.
- Play session stopped and the scriptable camera released; nothing left in Edit.

KNOWN LIMIT
PathfindingService will not route up the treads, so NPCs cannot follow a player into a hut. Not a regression (guards never entered huts) and not required by this job, but it means a hut interior is currently a spot enemies cannot reach.

NOT DONE, ON PURPOSE
The CAMPS own huts are still not enterable - same tread builder would do it, but camp buildings are yawed to face the fire (so their door can point at the sandbag ring) and treads there would land among the perimeter, posts and loot slots without any separation check. Written up as Planned/camp-huts-enterable.md.

### ✅ Auto-synced files

- `sync/ServerScriptService/World/VillageLayout.luau`
- `sync/ServerScriptService/World/CampDefs.luau`
- `sync/ServerScriptService/World/CampLayout.luau`
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`
- `ASSETS.md`
- `Planned/camp-huts-enterable.md`

### ⚠️ Manual Studio copy required

- _none_

## Proof it works better - MANDATORY (GROUND-RULES 7)

Evidence, not assertion. A claim here without data behind it means the job is not done.

| | |
|---|---|
**Before** | _screenshot / measurement / log_ |
**After** | _same camera, same state_ |
**What failure would have looked like** | _TODO_ |

- [ ] Captured in **PLAY**, not the editor
- [ ] Same camera and same game state in both
- [ ] Numbers where numbers are possible, not only screenshots

## Verification

- [ ] All mandatory gates in the implementation plan are ticked
- [ ] Independent reviewer agent run, and its finding recorded
- [ ] _TODO: anything else confirmed working_
