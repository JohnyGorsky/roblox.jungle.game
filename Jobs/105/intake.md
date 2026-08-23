# Job #105: Boat turret: widen the elevation arc (+30% up and down)

**Project**: `roblox.jungle`
**Created**: 2026-08-23 16:48:11
**Status**: Complete — implemented & verified in Play

## Requirements / goal

Reported: 'Boat turret has limitations to rotate down. When we ride boat is little bit up, and you cant target enemies near boat. So we must add +30% rotation up and down for turret.' The mounted gun's pitch arc is clamped to -12 deg / +35 deg RELATIVE TO THE BOAT, and BoatServer trims the hull bow-up by up to 7 deg under throttle, so while riding the effective down-aim shrinks to about -5 deg from level and close-in targets at water level cannot be brought under the crosshair.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
