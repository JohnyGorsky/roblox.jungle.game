# Job #007: P3: croc spawn director + multiple crocs

**Project**: `roblox.jungle`
**Created**: 2026-07-18 15:47:17
**Status**: ✅ Completed (2026-07-18)

## Requirements / goal

Generalize the single-croc POC (Job 006) into a spawn director: crocs spawn near/ahead of the boat as it travels, capped at a max active count, with a spawn rate that escalates with distance (the day/night/zone hook). Multiple crocs each run the existing chase/bite AI (single global tick over CollectionService Enemy-tagged crocs, per roblox-ai). Cull crocs left far behind. Server-authoritative. Builds on Job 006 (EnemyServer/EnemyDefs, boat HP, weapon). Greybox. Skills: roblox-ai (multi-agent tick, spawn/pool, perf), roblox-scripting.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
