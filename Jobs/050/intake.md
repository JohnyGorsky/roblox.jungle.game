# Job #050: River forks + small islands

**Project**: `roblox.jungle`
**Created**: 2026-07-19 19:58:50
**Status**: Requirements Gathering (intake)

## Requirements / goal

River journey overhaul #3. RiverData: deterministic fork set-pieces in wide zones (Delta) - branch separation ramps 0->max->0 over ~520 studs (smooth split/island/merge). branchesAt(z) returns 1 channel normally or 2 branches (~62% width each) around a low walkable island; forkOffsetAt(z). Suppress obstacle hooks + docks inside forks. RiverGenerator: per-z branches list; column is water if within ANY branch, land between = island, banks use nearest branch. No boat pathing change (water continuous, current still downstream). MAX_HALFW already covers the spread. Greybox. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
