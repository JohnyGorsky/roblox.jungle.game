# FINDING 0035: Culling a landing site destroys guards without calling EnemyRig.destroy, leaking AnimationTracks and Heartbeat work for the rest of the run

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-25 19:22:58

**Symptom:** The site cull drops guardState[d] and then calls model:Destroy() directly. EnemyRig's rigs table is strongly keyed by Model and is only pruned in EnemyRig.destroy, which that path never calls — so every culled guard leaves its AnimationTracks behind and stays in EnemyRig's per-frame pairs(rigs) Heartbeat loop for the rest of the run. Pre-existing (predates #119), but #119 makes it worse: the RocketMan is an 85-part rig with four loaded tracks, and CULL_BEHIND is 1200 studs so sites are culled routinely. Note tickGuard's own death path DOES do this correctly ('NOT :Destroy() — the rig holds AnimationTracks'), so the fix is to make the cull path match it: iterate the site's CampGuard descendants and call EnemyRig.destroy on each before destroying the model.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
