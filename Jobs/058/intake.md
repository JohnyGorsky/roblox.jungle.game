# Job #058: Solo tuning pass (scale threat by crew size)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 22:25:23
**Status**: Requirements Gathering (intake)

## Requirements / goal

From GAME.md decision (todo 0000): soloable but harder. A lone player can't man multiple stations (drive AND gun), so scale THREAT by crew size so solo is finishable while a full crew faces the full challenge. crewScale = 0.55 (1 player) → 1.0 (6 players), linear. Apply to EnemyServer sea/land caps and ExcursionServer camp guard counts (min 1). No player/boat buffs (keep it 'harder', not 'assisted'). Tunable. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
