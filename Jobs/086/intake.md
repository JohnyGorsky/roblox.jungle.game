# Job #086: Playtest fixes batch (enemy placement & behaviour)

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:11:55
**Status**: Requirements Gathering (intake)

## Requirements / goal

Collector job for playtest issues the user reports as they play. Items are logged in todo/ first, then pulled into this job's implementation plan once the batch is agreed. Do NOT start implementing until the user says the batch is closed and the plan is agreed.

ITEM 1 (todo 0046) - Wolves swim in open water. Land enemies are pinned to WATER_Y by stepToward() (EnemyServer.server.luau:184) and anchored only 8-20 studs past the bank with LAND_LEASH = 65, so they cross open river at water level to reach the boat. Two parts: (a) land creatures must follow ground height and never leave land; (b) per user direction, wolves should live at camps/bases rather than roam the bank pool - Bandit is the existing precedent (excluded from LAND_POOL, spawned by ExcursionServer as a CampGuard).

ITEM 1b (unconfirmed) - a dark shape on the boat deck beside the mounted turret in the same screenshot; needs identifying.

MORE ITEMS TO FOLLOW - the user said 'we will have more'.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
