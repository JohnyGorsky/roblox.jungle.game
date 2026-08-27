# FINDING 0044: End-zone tower chests still pay ~120 Salvage where there is no shop

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-27 21:07:39

**Symptom:** EndGarrison.luau:218-225 argues at length that the end-zone tower chests were changed from Salvage to Ammo BECAUSE Salvage buys nothing past z=17600 (there is no trading post in the end zone). But the Kind=Ammo pickup branch in ExcursionServer:1017 also calls awardSalvage(player, 40). Three chests therefore still hand out ~120 Salvage that can never be spent, and the file's own reasoning says that was the thing being fixed.
**Where:** sync/ServerScriptService/EndZone/EndGarrison.luau:218-225
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
