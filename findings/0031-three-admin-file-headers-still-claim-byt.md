# FINDING 0031: Three admin file headers still claim byte-identity across trees after diverging

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-25 13:13:14

**Symptom:** Found by the Job #117 reviewer.

Both AdminServer copies say 'IDENTICAL copy in both trees' at line 4, and the LOBBY AdminClient says 'IDENTICAL COPY IN BOTH TREES ... diff between the two must be silent'. All three are false: the game copies carry ~280 lines of game-only tooling (tpFirstCamp, tpEndBase, the Job #112 cheat toggles). Only the GAME AdminClient documents the divergence correctly.

Why it matters: the stale header is the one you read if you open the lobby file first, and acting on it -- copying one tree's copy over the other wholesale -- destroys the game-only tooling. Job #117 corrects the headers it touches; this finding records the class of problem.
**Where:** sync + lobby/sync ServerScriptService/Progression/AdminServer.server.luau, lobby/sync/.../UI/AdminClient.local.luau
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
