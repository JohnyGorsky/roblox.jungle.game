# Implementation Plan — Job #113

**Project**: `roblox.jungle`
**Created**: 2026-08-24 00:38:26
**Status**: Planning (awaiting go-ahead)

## Analysis

MEASURED, not assumed. Before (Play, 60 fps): terrain existed -600..+1800 studs around the boat, foliage 3352 parts reaching 839 ahead and 0 behind. Those are exactly RiverBootstrap AHEAD_CHUNKS=7/BEHIND_CHUNKS=2 and FoliageServer AHEAD=800/BEHIND=220, unchanged since the files were created in 05311ec (2026-07-18), so this was never a regression in these constants. Both scripts are server-side, so live players hit the same wall - it is not a Studio artifact. Studio quality was ruled out: Rendering.QualityLevel/EditQualityLevel read Automatic at a steady 60 fps, and pinning Level21 changed nothing measurable.

## Implementation steps

1. Raise RiverBootstrap AHEAD_CHUNKS 7->10 (1792->2560 studs) and BEHIND_CHUNKS 2->4 (512->1024)
2. Raise FoliageServer AHEAD 800->1200 and BEHIND 220->400, keeping the foliage window deliberately tighter than the terrain window
3. Update the stale '~1800 studs' cross-reference comment in ExcursionServer
4. Verify by measurement in Play on BOTH datamodels, not by eye
5. Report the client-side streaming cap found during verification and what is still owed (mobile profile, behind-window check under way)

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
