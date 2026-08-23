# FINDING 0017: Rejoining the same run re-seeds the loadout and destroys bought guns/ammo

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-23 16:29:23

**Symptom:** InventoryService.seed guards on the per-PLAYER attribute InvSeeded, which is gone when a player rejoins. A crew member who buys a 750-salvage shotgun plus shells, disconnects and rejoins the same reserved server is re-seeded to Axe+Torch with zero ammo, silently. Job #104 makes ammo a paid item, so this now loses purchased goods as well as looted ones.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
