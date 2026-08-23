# FINDING 0019: Village HP ramp is twice as steep as its own comment claims

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 16:29:24

**Symptom:** ExcursionServer:1714 'villageStep = VILLAGE_STEP ^ (index - 1)' uses the DOCK ordinal, but landings are odd docks only, so the exponent runs 0,2,4,6,8,10 rather than 0,1,2,3,4,5. The comment at :1747 describes village N as VILLAGE_STEP^(N-1). Effect: a landing-6 Bandit is ~143 HP, not ~89. Any combat tuning done against the documented curve is tuned against numbers that do not exist.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
