# FINDING 0043: Village strength ramps 1.21x per landing, not the 1.10x the comment records

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-27 21:07:29

**Symptom:** villageStep = 1.10 ^ (index - 1) uses the DOCK ordinal, but landings are only the ODD docks — so each successive landing is 1.10^2 = 1.21x the last, not 1.10x. The comment at :2461-2463 quotes the user direction as each next village +10% more monsters and stronger by 10%. The guard COUNT clamp hides it (saturates at MAX_GUARDS 6 from landing 4) but HP and bite damage keep compounding: x2.594 at landing 6 instead of the intended x1.61. Either the code or the recorded direction is wrong; they cannot both be right.
**Where:** sync/ServerScriptService/Excursion/ExcursionServer.server.luau:2470
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
