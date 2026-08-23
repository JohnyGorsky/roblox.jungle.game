# FINDING 0022: Dropping a gun leaves its ammo counter intact, so re-looting stacks ammoOnLoot

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-23 16:29:24

**Symptom:** InventoryService.drop:314-327 clears the slot but never the gun's ammoAttr. Ammo survives the drop, and picking the gun up again adds ammoOnLoot on top - a free top-up loop at any camp weapon crate.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
