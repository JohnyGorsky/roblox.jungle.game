# Job #009: P3: land threats + day/night cycle with strength scaling

**Project**: `roblox.jungle`
**Created**: 2026-07-18 16:10:15
**Status**: ✅ Completed (2026-07-18)

## Requirements / goal

A day/night cycle (Lighting.ClockTime, server-driven, Phase attribute). Threats scale strength with time of day (GAME.md): SEA threats (crocs) peak at NIGHT, LAND threats peak by DAY. Add a land enemy (panther) that ambushes from the banks (leashed to its bank anchor, can't chase across open water like crocs). Bite damage + spawn rate scale via EnemyDefs.strengthFor(category, phase). Generalize EnemyServer to spawn/tick both sea + land categories. Server-authoritative, greybox. Builds on Jobs 006/007/008. Skills: roblox-vfx (day/night lighting), roblox-ai (leashed ambush behavior).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
