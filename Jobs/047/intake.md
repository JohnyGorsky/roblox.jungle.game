# Job #047: Zone-driven river shape + turn variety

**Project**: `roblox.jungle`
**Created**: 2026-07-19 19:26:18
**Status**: Requirements Gathering (intake)

## Requirements / goal

River journey overhaul #1 (see Planned/river-journey-overhaul.md). RiverData: add a per-zone ZONE_PROFILE (width/turn/obstacle-density/currentMul) keyed at zone centers, interpolated by distance (continuous, no seams, aligned to ZoneServer boundaries H 0-4500 / Croc 4500-9000 / Rapids 9000-13500 / Delta 13500-18000). Rewrite centerlineX with a 3rd meander octave whose medium+fine octaves scale by per-zone turniness (fixes straight/predictable + Rapids snakes, Headwaters lazy). widthAt uses per-zone base (Rapids ~95 tight, Delta ~300 wide; clamp 80-330, hull beam 14 stays drivable). hooksBetween: dense candidate grid thinned by per-zone density. Add currentMulAt (wired into boat in job 2). RiverGenerator: bump MAX_HALFW to 170 for the wide Delta. Greybox. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
