# FINDING 0029: Destroyed generators do not reset when a new run starts

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-25 12:22:10

**Symptom:** Workspace.RunStarted flipping to true re-locks every bunker (Job #116, Bunkers.resetAll) but does NOT revive the generators: Generators.luau's rig keeps dead=true and the model keeps Disabled=true, so an admin-forced second run in the SAME server starts with three already-destroyed keys. Bunkers.resetAll therefore warns and re-opens rather than sitting shut over dead keys. Harmless in production (a real new run is a new server), but Generators.luau should grow its own RunStarted reset - full HP, hum back on, smoke off, DISABLED sign cleared - so the two systems agree. Measured in Play 2026-08-25: after the reset the doors returned to y=22.167 and the lamp to red, while G1/G2/G3 all still read Disabled=true.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
