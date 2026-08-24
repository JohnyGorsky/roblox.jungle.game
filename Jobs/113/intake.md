# Job #113: Deepen river streaming windows

**Project**: `roblox.jungle`
**Created**: 2026-08-24 00:33:28
**Status**: Requirements Gathering (intake)

## Requirements / goal

The visible world ends too close: terrain is generated only 1792 studs ahead / 512 behind the boat (RiverBootstrap AHEAD_CHUNKS=7, BEHIND_CHUNKS=2) and foliage only 800 ahead / 220 behind (FoliageServer AHEAD/BEHIND). Measured live 2026-08-24: terrain existed -600..+1800 studs relative to the boat, foliage 839 ahead and none behind, at 60 fps. Reported as 'terrain renders very close, everything spawns in front of me and is gone when I look back'. This is server-side, so live players see the same wall. Raise the windows (target AHEAD_CHUNKS 10, BEHIND_CHUNKS 4, foliage AHEAD 1200, BEHIND 400), verify by measurement in Play, keep the far edge hidden (no visible map edges), and report the instance/perf cost honestly with a mobile check still owed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
