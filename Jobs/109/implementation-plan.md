# Implementation Plan — Job #109

**Project**: `roblox.jungle`
**Created**: 2026-08-23 21:35:59
**Status**: Planning (awaiting go-ahead)

## Analysis

MEASUREMENTS (Studio, live library, re-run correctly for this job)
- Every Bahay Kubo ships with its OWN staircase at its entrance. Detected by walking a probe inward from 32 studs at each of 360 bearings, casting a LOW ray (from floor+2, down floor+2.5) and keeping the bearing whose height profile starts on open ground, ends on the floor, and has the smallest single-stud rise. Result: BahayKubo1 bearing 212 (biggest step 0.87), BahayKubo2 208 (1.00), BahayKubo5 160 (1.00) - all inside the ~2-stud ledge a Humanoid climbs without jumping.
- TWO WAYS THAT MEASUREMENT GOES WRONG, both hit during this job: cast from well above the floor and the ROOF EAVES answer first, reporting a 9-11 stud step; sample only 18 studs out and BahayKubo5 (29.6x34.0) is still standing on its own deck, so every bearing reads flat and the search returns nonsense.
- The Job #108 'door' bearings were the widest CLEAR ARC, which is not the same thing. Near the stairs on Kubo1/Kubo2 (223 vs 212, 213 vs 208) so the error hid; 152 degrees out on Kubo5 (312 vs 160), i.e. that hut was being turned with its steps facing away from everything.
- Guard seating: spawnGuard/tickGuard seat every guard at groundAt(x,z) + size/2, and groundAt only sees TERRAIN. A bandit standing on a hut floor 3.5 studs up is therefore re-seated onto the dirt between the stilts on its first tick.
- Bandit def: aggroRadius 95, biteRange 12, speed 20. 95 studs of sight means an ambusher leaves the house and meets the player in the open long before they reach the village.
- Damage is written to a custom character HP ATTRIBUTE, not Humanoid.Health. A test that watches Humanoid.Health sees nothing and concludes the enemy is passive.
- Salvage sources: ExcursionServer.awardSalvage (all loot/stash/weapon/ammo), the nugget +30, KillReward +6 per land kill, ObjectiveServer, and SalvageServer's DISTANCE DRIP of 1 per 60 studs for the whole 18000-stud run.

DECISION ON THE MESSAGE PLUMBING: explicit per-reward calls, NOT a client watcher on the Salvage attribute. A watcher is fewer lines and catches every source automatically, but the distance drip would then toast every few seconds forever, and a delta cannot name what you picked up (+40 cannot say Gasoline). The drip simply never calls the notifier.

TEST-HARNESS TRAPS worth recording, all three cost time here: (1) execute_luau on client and server are separate contexts and separate MCP round trips - a server task.delay(3) fires before the client listener is connected, which reads exactly like a broken remote; use a 20s delay. (2) StreamingEnabled is ON, so a crate the server can see may not exist on the client, and InputHoldBegin on an unstreamed prompt silently does nothing. (3) A ModuleScript edited after Play has started keeps its CACHED body even though .Source shows the new text - restart Play before concluding a module change did not work.

## Implementation steps

1. Replace CampDefs.VILLAGE.door with .entrance carrying the measured STAIR bearing and floor rise, and delete CampDefs.VILLAGE.step. Keep the wrong-turn history in the comment - the bearing being 'the widest clear arc' is exactly the kind of plausible substitute that shipped once.
2. Delete the EntryStep treads from buildVillageHut. Nothing replaces them: the models' own stairs are the entrance. VillageLayout keeps choosing yaw from the entrance outward (aimed at the walking route, jittered +/-70) so the existing stairs face the player.
3. Add CampDefs.VILLAGE.dressing: a weighted rock/log/bush/fern/palm list, 5-9 per hut, in a band of 1.25-2.6 hut half-diagonals, with a HARD keep-out wedge of 34 degrees around the entrance bearing so the fix for item 1 is not undone by a boulder. Rocks and logs collide (cover), plants do not (no invisible-wall mazes). Generated in VillageLayout so it can vet each slot against the path and the neighbouring huts.
4. Widen VillageLayout.blocked to the dressing band, not just the building - the basin's interior tree scatter runs before the huts are built and would otherwise plant a palm on a boulder we placed.
5. Add CampDefs.VILLAGE.yardLoot: 3-5 small salvage barrels outdoors among the clutter, 12-22 salvage, deliberately below the 25-40 of an interior stash - what you can see from the path should pay less than what you went inside for.
6. New ServerScriptService/Economy/RewardFeed.luau: one RemoteEvent, notify(player, kind, label, amount). Called from awardSalvage (covers every loot/stash/weapon/ammo payout), the gold nugget, the resource pickup (names the cargo), the weapon and ammo grants, KillReward, and ObjectiveServer. NOT from the distance drip.
7. New StarterPlayerScripts/UI/RewardFeed.local.luau: a small stacking feed directly UNDER the currency chips, top-right, so the message sits beside the counter it explains. Fixed pool, oldest recycled, fewer rows on touch - the same discipline CrewToast follows.
8. Hut ambushers: CampDefs.VILLAGE.bandits (count 2, aggro 24 against the def's 95). Two randomly chosen huts per landing site, picked by a shuffle so two distinct huts are always used. Each is its OWN camp for alert and chase-slot purposes, so shooting one does not wake the garrison 200 studs away, and none is registered in garrisons, so none respawns.
9. Perched guards: add perch/perchModel to GuardState so a hut bandit holds its floor height instead of being re-seated onto the terrain under the house. It must SET seatY and fall through, never return - an early return skips the bite and the ambusher politely declines to attack.
10. The perch release test is a RAYCAST FOR FLOORBOARDS UNDERFOOT, not a radius. A flat 14-stud radius was tried and measured: the bandit committed, walked 6.8 studs out of its doorway and was still 5.2 studs above the ground. No radius can describe a 24x14 floor.
11. Verify all four in PLAY: zero EntryStep parts in the site; walk into a hut on its own stairs with Jump never pressed; loot a yard crate and a stash and read the rendered feed row; kill a guard and read the rendered feed row; and the ambusher must hold its post at 45 studs, damage the player when they step onto the floor, and never float off the floorboards.

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
