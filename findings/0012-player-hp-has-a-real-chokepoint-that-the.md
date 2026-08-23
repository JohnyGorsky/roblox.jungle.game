# FINDING 0012: Player HP has a real chokepoint that the grace window does not use

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 13:14:01

**Symptom:** PlayerCombat's GetAttributeChangedSignal('HP') handler already sees EVERY write to player health from every script, present and future - it is the one true chokepoint. Job #103 enforces the post-revive grace at the two damage SITES instead (EnemyServer.nearestPlayer, ExcursionServer.tickGuard), which covers 100 percent of today's damage surface but means a damage path added later silently punches a hole in the invincibility. A decrease-veto in that handler would close it, and contrary to the note written during #103 it would NOT fight the heal loops: RoleServer and CampfireHeal only ever INCREASE HP. Keep the per-site guards too - they carry semantics the chokepoint cannot (not redirecting a spent bite into the hull, suppressing the red damage number). Related trap for any future consumer: InvincibleUntil is a NUMBER on the Workspace:GetServerTimeNow() clock and the attribute can linger past expiry, so 'if char:GetAttribute(...)' is wrong; only a '< deadline' comparison is correct.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
