# Job #114: Admin panel: TP to Endgame (end-zone bunker spawn)

**Project**: `roblox.jungle`
**Created**: 2026-08-25 00:08:19
**Status**: Requirements Gathering (intake)

## Requirements / goal

User request: add a new command to the admin panel that teleports you to the endgame — specifically to `Workspace.EndBase.Bunker.SpawnPoint2` (measured at 310, 18.5, 18292; terrain under it at y=18.00).

Decisions taken with the user (wizard, 2026-08-25):
- The jump ALSO force-starts the run via the existing `ServerStorage.ForceStartRun` hook when `Workspace.RunStarted` is not set, so the extraction pad (EscapeServer's occupancy loop only counts while RunStarted and not RunEnded) is live on arrival.
- The BOAT is NOT moved — the end zone is hand-built editor terrain (z > END_ZONE_Z_START = 18000), so nothing there needs the river generation window dragged downstream.
- Button sits directly under 'TP to First Camp', labelled 'TP TO ENDGAME', flag icon.

Constraints:
- Game place only (`sync/`); `Workspace.EndBase` does not exist in the lobby place.
- StreamingEnabled is TRUE in the game place, so pre-stream the destination before moving the character.
- Server re-checks the admin allowlist (AdminDefs) on every action; this action is a SELF teleport (no target selector).

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
