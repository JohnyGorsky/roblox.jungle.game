# FINDING 0041: The 550 HP end-zone warlord pays the same 6 salvage as a boar, in a currency that cannot be spent

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-27 19:40:30

**Symptom:** KillReward.LAND_SALVAGE is a flat 6 and its header says 'deliberately not scaled by toughness'. That was fine when every land kill was a 40-55 HP animal. Job #121 adds a 550 HP boss who gates the win, and there is no trading post past z=17600 - so the reward for the game's hardest fight is 6 units of a currency the run is about to end with. Pre-existing rule, newly visible.
**Where:** sync/ServerScriptService/Economy/KillReward.luau LAND_SALVAGE
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
