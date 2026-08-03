# FINDING 0005: Lobby place still has Gotham fonts in LobbyLoading and RankServer

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-03 00:00:19

**Symptom:** Job #075 removed every Enum.Font.Gotham from the GAME tree. The LOBBY tree still has three: lobby/sync/ReplicatedFirst/LobbyLoading.local.luau (lines 84/96/132) and lobby/sync/ServerScriptService/Progression/RankServer.server.luau (228/241/266). LobbyLoading has the same legitimate excuse GameLoading does - it runs from ReplicatedFirst and cannot require Theme from ReplicatedStorage without blocking on the replication it exists to hide - so it should get the same treatment: hand-copied palette values plus a header note, not a require. RankServer builds GUI labels server-side and CAN require Theme. Out of scope for #075, which was the game place.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
