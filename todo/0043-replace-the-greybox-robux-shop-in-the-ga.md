# TODO 0043: Replace the greybox Robux shop in the GAME place with the real lobby shop

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 21:53:55

User call (Job 073 playtest): the game-place Robux kiosk is still a green greybox block with a 'ROBUX SHOP' billboard, built by sync/ServerScriptService/Economy or Staging StartShopServer.server.luau. The LOBBY already has the real thing - lobby/sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau, which shows real store art per row (Job 065 phase 2) using the transparent in-game product icons recorded in ASSETS.md 5.1. Use THAT, not a new design. ASSETS.md 5.1 currently records the game copy as 'still text-only (out of scope)' - update that row when this lands. Watch out: the product/pass ids live in ReplicatedStorage/Progression/MonetizationDefs.luau which is meant to be byte-identical in both trees, and the kiosk MODEL also wants to stop being a greybox block (StartShopServer positions it away from the wreck, Job 072).
