# FINDING 0021: WeaponClient hardcodes AmmoPistol/AmmoShotgun instead of deriving from ItemDefs

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-23 16:29:24

**Symptom:** WeaponClient.local:251-252 hand-writes both ammo attribute names for its crosshair state, while InventoryHud:278-282 correctly iterates ItemDefs.Items and reads ammoAttr. A third gun, or an ammoAttr rename, leaves the crosshair reading the wrong pool.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
