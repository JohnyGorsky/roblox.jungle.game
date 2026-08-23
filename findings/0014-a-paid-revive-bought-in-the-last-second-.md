# FINDING 0014: A paid revive bought in the last second is refused and the player dies for the run

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 13:14:02

**Symptom:** If a selfRevive receipt clears after bleedFor has elapsed, PlayerCombat's bleedThread has already nulled pendingRevive and set hum.Health = 0, so grantSelfRevive returns false, MonetizationServer returns NotProcessedYet and the player is correctly NOT charged - but they are permanently dead for the run. DownedHud's PANIC_SECONDS = 10 actively encourages exactly this last-second purchase, so it is reachable. Presents to the player as 'I paid and died anyway'. Found by the Job #103 damage audit.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
