# Implementation Plan — Job #114

**Project**: `roblox.jungle`
**Created**: 2026-08-25 00:09:14
**Status**: Planning (awaiting go-ahead)

## Analysis

Two files, both under auto-synced paths, GAME tree only (sync/). The end zone is hand-built editor content past RiverData.END_ZONE_Z_START (18000): Workspace.EndBase.Bunker.SpawnPoint2 measured at (310, 18.5, 18292) with Terrain at y=18.00 directly under it, and Objects.Plane.Escape (the extraction pad marker EscapeServer builds on) 81 studs away. Nothing there is generated or culled, so unlike 'TP to First Camp' this jump does NOT need to drag the boat/generation window downstream — it needs three things only: the run running (or the pad is inert), the region streamed (StreamingEnabled=true), and the admin out of the driver seat (a seated character is welded to the boat and a CFrame write does nothing).

## Implementation steps

1. AdminServer.server.luau: add a 'tpEndBase' branch after 'tpFirstCamp' — allowlist already re-checked at the top of OnServerInvoke. Find Workspace.EndBase, then SpawnPoint2 BY NAME recursively (same editor-placed-fitting contract EscapeServer uses); return 'no-endbase' in the lobby tree and 'no-spawnpoint' if the marker is gone.
2. AdminServer: force-start the run via ServerStorage.ForceStartRun when Workspace.RunStarted is not true, so EscapeServer's occupancy loop (RunStarted and not RunEnded) actually counts the arriving admin; report startedRun back to the client.
3. AdminServer: unseat the character (Humanoid.SeatPart -> Sit=false, yield a beat) before writing the CFrame.
4. AdminServer: raycast down from the marker (+60, -400) excluding the marker and the character to seat the arrival on the real floor, then RequestStreamAroundAsync(dest, 10) in a pcall, then set HumanoidRootPart.CFrame to floor + 4 studs; print an audit line and return { ok, startedRun, streamed }.
5. AdminClient.local.luau: add { label = 'TP to Endgame', icon = 'flag', action = 'tpEndBase' } directly under the 'TP to First Camp' row — the existing a.action path already reads the result, keeps the panel open on failure with the error on the button, and closes it on success.
6. Note in the AdminClient header that the two trees have already diverged (Jobs #107/#112 landed game-side only) so nobody copies the older lobby file over this one.
7. Verify in PLAY (game place): press the button from the spawn base, confirm arrival at ~(310, 22, 18292) inside the bunker area, confirm the console prints the [Admin] end-zone line, then walk 81 studs to the extraction pad and confirm the sign counts 1/1 aboard and extraction fires (RunStarted was set by the jump).

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
