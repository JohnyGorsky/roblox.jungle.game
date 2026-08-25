# FINDING 0034: RocketFx builds full blast VFX for every rocket at any range, and its near-blast debounce is shared between the player's rocket and the enemy's

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-25 19:22:43

**Symptom:** Job #118 deliberately exempted RocketFx.blastFx from any distance gate ('the blast must always be visible', findings/0033) because the Bazooka was a player weapon fired ~6 times a run. Job #119 added a PERMANENT enemy that fires every 20 s, one per live landing site, with CAMP_AHEAD = 1400 — so every client now builds ~4 parts + 2 emitters + a PointLight + a Sound for explosions it often cannot see. Separately, RocketFx's NEAR_DEBOUNCE (4.0 s) and lastNear are shared across ALL rockets, so an enemy shell landing on you can be silenced by your own shot 3 s earlier. Not fixed in #119: RocketFx is the player weapon's client script, out of this job's scope, and the no-distance-gate decision is documented and deliberate. Fix would be a camera-distance gate on the heavy VFX only (keep the sound, which already has rolloff) plus a separate debounce slot for enemy-fired rockets.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
