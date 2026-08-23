# Job #111: Extraction endgame: escape pad wins the run

**Project**: `roblox.jungle`
**Created**: 2026-08-23 22:37:05
**Status**: Requirements Gathering (intake)

## Requirements / goal

Replace the greybox yellow FinishLine with a real extraction. Remove RiverBootstrap.placeEnd(). Build a shiny lobby-style extraction pad (gold) on the editor-placed marker Workspace.EndBase.Objects.Plane.Escape. A player standing on the pad becomes invincible via the existing InvincibleUntil attribute. When every LIVING crew member is on the pad - or a player aboard holds the launch prompt once a majority is on - the run WINS: the existing results screen shows unchanged. RunServer no longer wins on BoatDistance >= END_DISTANCE.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
