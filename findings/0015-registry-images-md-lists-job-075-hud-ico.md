# FINDING 0015: Registry images.md lists Job #075 HUD icons as PENDING though all 16 ids landed in Theme.luau

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 15:52:10

**Symptom:** Registry Assets/registry/images.md still shows the 16 Job #075 in-run HUD icons as pending with empty ids and placeholder fallbacks, while sync/ReplicatedStorage/UI/Theme.luau has had all 16 real ids since 2026-08-16 (iconPending is empty). A stale registry defeats the 'grep the registry before sourcing' rule - Job #104 nearly re-sourced ammo icons because of it. Reconcile images.md against Theme.icon.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
