# Job #048: Per-zone river current

**Project**: `roblox.jungle`
**Created**: 2026-07-19 19:43:05
**Status**: Requirements Gathering (intake)

## Requirements / goal

River journey overhaul #2. Wire RiverData.currentMulAt(z) (added in #047) into BoatServer: current.Force = downstream(z) * CURRENT * currentMulAt(z). The Rapids sweep the boat downstream faster (x1.5), the Lost Delta slows (x0.8), others x1.0. One-line change; boat-physics tested. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
