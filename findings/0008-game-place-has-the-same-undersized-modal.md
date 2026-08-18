# FINDING 0008: GAME place has the same undersized modal controls the lobby just fixed

**Project:** `roblox.jungle`
**Status:** fixed (2026-08-18)
**Severity:** med
**Created:** 2026-08-18 16:38:23

**Symptom:** Job #095's lobby sweep found Components.panel's Close button at 40x40 and every shop row's BUY button at 84x34, both under the 58px thumb floor. The GAME tree has its own copy of ReplicatedStorage/UI/Components.luau with the SAME code, used by DockShopClient and the in-game RobuxShop. Job #094 audited the GAME place but only swept the always-on HUD - modal panels were never opened during that sweep, so this was missed there. Fixed in the lobby copy only (Job #095 is LOBBY-scoped; crossing into sync/ needs its own permission). The GAME place is still affected: a mobile player cannot comfortably close a dock shop or hit a buy button.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
