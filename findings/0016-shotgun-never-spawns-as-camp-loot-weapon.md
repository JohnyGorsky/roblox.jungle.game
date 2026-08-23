# FINDING 0016: Shotgun never spawns as camp loot: weapon-crate parity check can never be true

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-23 16:29:23

**Symptom:** ExcursionServer:1816 picks the deep-camp weapon crate with 'if index % 2 == 0 then Shotgun else Pistol', but index is the DOCK ordinal and only ODD docks are landings (RiverData:319 'landing = (i % 2) == 1'; ExcursionServer's own comment at :1747 says landings are docks 1,3,5...). So the branch is dead code: every weapon crate is a Pistol, and because the ammo crate at :1826 uses the same weaponId, ALL handheld ammo loot is Pistol ammo. The shotgun and its ammo are obtainable ONLY from the trading post. Found while adding buyable ammo (Job #104). Fix: derive from tier (:1701) or from what the player carries.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
