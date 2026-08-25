# FINDING 0030: Robux shop stays open through the results screen (nothing closes it on RunEnded)

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-25 13:13:13

**Symptom:** Found by the Job #117 reviewer, out of that job's scope.

The game-place RobuxShop force-closes when the character goes Downed (its documented difference 3) but nothing closes it on Workspace.RunEnded. RunServer holds the results screen for RETURN_TIMEOUT = 30 s before returning the party to the lobby, so a player can sit in the Robux shop and buy things during it — including anything whose grant is meaningless once the run is over.

Job #117's M16 rows are safe (guarded by the M16Granted attribute), which is why this was not fixed there.

Fix shape: the same watcher that already reacts to Downed should also react to Workspace.RunEnded.
**Where:** sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
