# FINDING 0013: Going down while carrying cargo never clears the Busy attribute

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 13:14:01

**Symptom:** ExcursionServer sets player Busy while carrying loot, and clearCarry only runs on death or on leaving - not on entering the downed state. A player who is downed mid-haul and then revived comes back still flagged Busy, which blocks both the gun and the axe. Surfaced by the Job #103 damage audit while tracing what is and is not reset across a revive.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
