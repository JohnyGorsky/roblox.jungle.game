# FINDING 0042: The hunter objective cannot be completed by raiding — RunKills ignores camp combat

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-27 21:07:25

**Symptom:** The hunter objective reads Take down 15 threats and pays 120 Salvage, but RunKills is incremented in exactly ONE place: EnemyServer.server.luau:460, the river-creature tick. ExcursionServer contains zero RunKills writes. So camp guards, hut ambushers, Rocket Men, generators and the whole end-zone garrison do NOT count. Only river Boars and sea creatures do. 120 Salvage is gated behind a counter that ignores most of the game's combat. Found by the independent reviewer on Job #123, where it changed the stop-2 Salvage budget by 120.
**Where:** sync/ServerScriptService/Enemies/EnemyServer.server.luau:460
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
