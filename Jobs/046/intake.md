# Job #046: Start-area Robux shop at the crash-site hub

**Project**: `roblox.jungle`
**Created**: 2026-07-19 19:06:11
**Status**: Requirements Gathering (intake)

## Requirements / goal

Step 5 of game-intro-sequence. Add a small Robux shop at the start area (crash-site hub) by the boat. Game server StartShopServer waits for HubSpawn, builds a greybox kiosk on the platform with a labelled ProximityPrompt, creates an OpenRobuxShop RemoteEvent fired to the triggering player. Game client RobuxShop (adapted copy of the lobby RobuxShop.local) opens on that remote - Gold packs (dev products) + game passes from the shared MonetizationDefs, real MarketplaceService prompts; ProcessReceipt already handled by the game MonetizationServer. Kiosk-access only (no always-on button). Greybox. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
