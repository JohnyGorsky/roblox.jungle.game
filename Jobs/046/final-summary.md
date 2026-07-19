# Final Summary — Job #046: Start-area Robux shop at the crash-site hub

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Step 5 of the
game-intro-sequence (`Planned/game-intro-sequence.md`). Game place. Greybox.

## What
A small Robux shop at the start area (crash-site hub, by the boat) — the "small shop there" from the intro
vision. Walk up to a greybox kiosk, hold the prompt, and the Robux shop opens (Gold packs + game passes with
real MarketplaceService prompts).

## Implementation
- **`sync/ServerScriptService/Economy/StartShopServer.server.luau`** (new): waits for `HubSpawn`, raycasts to
  sit a greybox **kiosk** on the platform (~13 studs from the spawn, by the boat), gives it a floating
  "ROBUX SHOP" `BillboardGui` label + a `ProximityPrompt` (hold 0.2s, range 12). Creates the
  `ReplicatedStorage.OpenRobuxShop` RemoteEvent; the prompt fires it to the triggering player.
- **`sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau`** (new — game copy of the lobby panel):
  same panel (GOLD PACKS + PASSES from the shared `MonetizationDefs`, real `PromptProductPurchase` /
  `PromptGamePassPurchase`, unset IDs show "Soon"), but opened by `OpenRobuxShop` (kiosk) instead of an
  always-on corner button. Receipts are already handled by the game `MonetizationServer` — no new purchase
  server logic.

## Verified (live in Studio — game place)
- [x] Analyzer-clean.
- [x] Kiosk built on the platform (`hasPrompt=true`, ~13 studs from `HubSpawn`, by the jetty/boat), labelled
      "ROBUX SHOP".
- [x] Firing the kiosk's `OpenRobuxShop` opened the panel over the game: **GOLD PACKS** 10/25/60/150 Gold
      (R$49/99/199/449) + **PASSES** Armored Boat (R$499), Boat Paint (R$99), Cosmetic Bundle (R$249) — real
      prices; close (X) works.
- [x] Kiosk framed in-world: reads as a start-area stall next to the awake player.

## Notes / follow-ups
- **Not committed.**
- **Kiosk-access only** (no always-on corner button in-game, unlike the lobby) — matches "a shop *there*". Easy
  to add a persistent button later if wanted.
- Real purchases only complete on the published place (Studio can't transact); prompt wiring + receipts are in
  place from Job 027.
- Greybox kiosk — art pass swaps it for a real stall model.
- This completes the mechanics for the whole game-intro-sequence; remaining is the **art/asset pass** (real
  plane, VFX, environment, animations, real shop model) + wiring `WorldBuilt` when a river generator exists.
