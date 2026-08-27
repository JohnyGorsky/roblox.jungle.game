# FINDING 0039: Rocket man stands 1.19 studs above the tower deck

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-27 19:40:30

**Symptom:** Measured in Play 2026-08-27 (Job #121): every RocketMan's feet sit at y=62.19 while the tower platform floor under him reads 61.00, so he hovers 1.19 studs. Cause is not new: spawnRocketMan seats him on the Defender pad's TOP FACE, and the editor-placed pad sits 0.69 above the floor and is 1 stud thick. Applies to camp towers identically (deck y=54.26 there). Fix would be to seat on the pad's BASE, or on the platform floor found under the pad.
**Where:** sync/ServerScriptService/Excursion/ExcursionServer.server.luau spawnRocketMan
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
