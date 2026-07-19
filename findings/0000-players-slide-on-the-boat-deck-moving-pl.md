# FINDING 0000: Players slide on the boat deck (moving-platform slip)

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-07-19 17:49:27

**Symptom:** Standing (not seated) on the boat, the player slowly slides across the deck. Cause: the boat is a SERVER-owned physics assembly that keeps drifting (CURRENT downstream force in BoatServer, line ~254) whenever it's not tied/anchored — and a CLIENT-owned character standing on a server-owned MOVING part doesn't get carried smoothly (Roblox moving-platform support breaks across network ownership + replication lag), so the deck slides under the player's feet. Most noticeable at a dock when untied (engine off at low fuel, current still drifts it) but applies any time the boat moves. Candidate fixes (physics-delicate — roblox-physics skill): (a) auto-hold/anchor the boat when idle near a dock, or zero CURRENT when nearly stopped; (b) while aboard + unseated, weld/AlignPosition the character to the boat (carry them); (c) hand the boat's network ownership to a rider (conflicts with server buoyancy stability). Needs a careful dedicated job; test against the boat-physics gotchas (never anchor a dynamic boat with a client-owned rider — that was the earlier disappear bug).
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
