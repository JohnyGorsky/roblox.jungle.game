# FINDING 0040: RunKills counts only river wildlife, never camp guards or the end-zone garrison

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-27 19:40:30

**Symptom:** RunKills is incremented at EnemyServer:387 only. ExcursionServer.tickGuard's death path never touches it, so no Bandit, Wolf, RocketMan, hut ambusher, BanditBoss or any camp guard has ever counted. ObjectiveServer:113 reads RunKills for the 'hunter' objective (take down 15 threats), so the hardest fights in the game contribute nothing to it. Noticed while verifying Job #121, whose 14 end-zone kills all score zero.
**Where:** sync/ServerScriptService/Enemies/EnemyServer.server.luau:387 vs ExcursionServer.tickGuard
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
