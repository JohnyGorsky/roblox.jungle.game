# FINDING 0032: Pressing Q permanently destroys a Robux-bought weapon, with no confirmation

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-25 15:44:08

**Symptom:** Raised by the independent reviewer on Job #118 and verified. InventoryService.drop refuses ONLY the Axe (the sword is the permanent fallback); every other slot is droppable, and InventoryHud binds Q straight to it with no confirm step. So one mis-key deletes a weapon the player paid Robux for. It cannot come back that run either: RifleGrant.tryGrant returns immediately when Granted_<key> is true, and that attribute is set before the grant. Affects the M16 (150 R$ pass / 30 R$ per run) today and the Bazooka (250 R$ / 80 R$) from Job #118. Finding 0022 is adjacent: drop never clears the ammo attribute either, so AmmoBazooka survives on a player with no launcher. Fix idea: a noDrop flag on ItemDefs entries, checked in drop() the same way the Axe is - or clear Granted_<key> on drop so the grant can re-fire. NOT fixed in Job #118: the owner scoped that job to the Bazooka plus one other money bug (2026-08-25).
**Where:** sync/ServerStorage/Inventory/InventoryService.luau:326 (drop) + sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau:318 (the Q bind)
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
