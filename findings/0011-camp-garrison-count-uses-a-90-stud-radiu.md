# FINDING 0011: Camp garrison count uses a 90-stud radius, but reinforcements spawn at 96-114 studs

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 12:25:53

**Symptom:** ExcursionServer's respawn loop counts a camp's living garrison with GUARD_COUNT_RANGE = 90 studs from campPos. CampLayout puts reinforcement entry points at radius + 26..40 where radius is 70-76, i.e. 96-114 studs out - so a reinforcement is NOT counted as alive until it has walked in to its post. Same blind spot for a guard chasing a player out to the GUARD_LEASH_ALERT of 250. Both make the camp read as short-handed when it is not, which is the 'i landed on camp and 7 enemies attacked me' direction. GUARD_COUNT_RANGE cannot simply be raised: near and deep camps sit 184 studs apart, so anything above ~92 starts counting the other camp's guards. The exact fix is to count by camp membership instead of by distance - guardState[guard].camp already holds each guard's camp position. Deliberately left alone in Job #102, which was fixing the opposite symptom (no reinforcements at all); noted so it is not lost.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
