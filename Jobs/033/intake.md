# Job #033: Enemy roster + tougher spawn director

**Project**: `roblox.jungle`
**Created**: 2026-07-19 16:19:29
**Status**: Requirements Gathering (intake)

## Requirements / goal

Deepen combat: add 2-3 new data-driven enemy types reusing the existing bite/leash AI (e.g. Piranha - sea, fast, low HP, swarms; River Hippo/Serpent - sea, slow, tanky, big bite; Boar/Raptor pack - land, fast). Spawn the right mix by zone/distance + time of day (EnemyDefs.strengthFor). Add escalation: bigger caps + a NIGHT surge / mini-wave. Keep server-authoritative + data-driven (EnemyDefs + EnemyServer). Enemy health bars already exist. POC greybox bodies.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline)
- [x] Implementation completed — 3 new enemy types + weighted-by-distance pools + distance/night caps verified
      live (Piranha swarm, deep-only RiverHippo, Boar; sea 7 / land 4 deep); analyzer-clean
- [x] Final summary + changelog written
