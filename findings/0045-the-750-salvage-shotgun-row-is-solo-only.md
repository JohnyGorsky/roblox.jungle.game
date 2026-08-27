# FINDING 0045: The 750-Salvage Shotgun row is solo-only content by arithmetic

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-27 21:07:44

**Symptom:** Measured on Job #123: every loot source at a landing site is one object, one looter, and the loot pool does NOT scale with crew size — nothing in buildLandingSite reads player count except the guard-count scale. Only the drip (54/leg) and objectives are per-player. So a 4-player crew member earns ~235 per stop against a solo player's ~777. They need ~4 stops to afford the 400 Pistol and essentially never afford the 750 Shotgun inside a 6-stop run. Either the pool should scale with crew size, or prices should, or this is accepted as intended — but it is currently undocumented and it caps what any multi-crew shop row can cost.
**Where:** sync/ReplicatedStorage/Economy/ShopDefs.luau:82
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
