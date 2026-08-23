# FINDING 0018: Re-buying an owned gun still tops up its ammo, at 6x the price of the ammo row

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 16:29:23

**Symptom:** InventoryService.grant:346-353 grants ammoOnLoot when the gun is already owned, so buying a second Pistol costs 400 salvage for 24 rounds while the new Pistol Ammo row gives 18 for 60. Harmless but confusing; it was the ONLY way to buy ammo before Job #104. Consider refusing a duplicate gun purchase (or refunding to the ammo row) now that a real ammo row exists.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
