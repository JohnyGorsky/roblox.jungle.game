# TODO 0036: REQUIRED (Job 068 E1): Greybox RunwayMarkings double-paints the real runway; Spawn.Pad still greybox

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 11:32:33

Found by the Job 068 live sweep, 2026-08-02. Scenery.RunwayMarkings still holds 13 greybox parts (9 Dash at 3x0.2x14 + 4 Threshold at 1.6x0.2x10, SmoothPlastic CREAM), first Dash at z -360. The five user-made RunWay tiles span z -154 to -485, so the greybox dashes sit ON TOP of the real painted runway. ASSETS.md 1.8 records the runway 27 + stripes as done by the user, so RunwayMarkings is pure leftover. Also still greybox: Stations.Spawn.Pad (2x26x26, colour 200,163,106 = SAND exactly, Sand material) -- confirm whether the sand spawn disc is intentional or the greybox original. Both are safe to delete: nothing reads them by name (the load-bearing list is PartyPad_*.Center, Dock.Pier, FirePit, Leaderboard_TopRuns.Board, Watchtower model names).
