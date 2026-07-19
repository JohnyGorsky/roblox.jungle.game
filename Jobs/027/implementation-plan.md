# Job #027 — Implementation plan: Robux monetization (Gold packs + Armored Boat + cosmetics)

**Project**: `roblox.jungle` · POC · Design source: Job #020 §6 (locked decisions) · Depends on #021/#022/#025.

## Products (placeholder IDs → fill after creating on Creator Hub)
**Gold packs — developer products** (repeatable), Bonds-parity Robux:
| id | Gold | Robux |
|----|-----:|------:|
| pack10 | 10 | 49 |
| pack25 | 25 | 99 |
| pack60 | 60 | 199 |
| pack150 | 150 | 449 |

**Game passes** (one-time):
| key | Name | Robux | Effect |
|-----|------|------:|--------|
| armoredBoat | Armored Boat | 499 | **+20% hull HP & +20% mounted-weapon damage** (the one power item) |
| boatPaint | Boat Paint Pack | 99 | cosmetic hull colours (stub — no cosmetic system yet) |
| cosmeticBundle | Cosmetic Bundle | 249 | trails/FX/emote (stub) |

All IDs default to **0** (unset) in `MonetizationDefs`; the shop skips unset products and ownership checks
are guarded, so nothing breaks pre-publish. The Creator-Hub checklist (full names/descriptions/prices) goes
in the final summary per the "full details" rule.

## Files
**Both trees:**
- `ReplicatedStorage/Progression/MonetizationDefs.luau` — catalog (gold packs + game passes, IDs, Robux, gold). NEW.
- `ReplicatedStorage/Progression/ProfileConfig.luau` — add `purchaseIds = {}` (dev-product idempotency). EDIT.
- `ServerScriptService/Progression/MonetizationServer.server.luau` — `MarketplaceService.ProcessReceipt`
  (idempotent gold grant, persisted); game-pass ownership check on join + `PromptGamePassPurchaseFinished`
  → `Owns_<key>` player attribute. NEW.

**Lobby:**
- `StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` — "ROBUX" button + panel: gold packs
  (`PromptProductPurchase`), game passes (`PromptGamePassPurchase`); unset products show "Soon". NEW.

**Game:**
- `ServerScriptService/Boat/BoatModules.server.luau` — EDIT `apply()`: if any crew owns the Armored Boat,
  `MaxHP *= 1.2`, set `GunDamageMul = 1.2` (combat reads later), add visible armor plating.

## Verification (Studio — partial by nature)
- Analyzer-clean (both trees).
- `ProcessReceipt` idempotency + gold-grant logic verified by **simulating a receipt** (call the handler with
  a fake receipt table) → gold granted once, repeat PurchaseId ignored.
- Armored-boat effect verified by setting `Owns_armoredBoat` + starting a run → `MaxHP` ×1.2, `GunDamageMul=1.2`,
  plating present.
- **Real Robux prompts (dev products / game passes) can only be confirmed on a PUBLISHED place** with valid
  IDs — flagged for a live playtest.

## Out of scope
Real cosmetic application (paint/trails/FX) — ownership tracked, visuals later; the actual Creator-Hub asset
creation (user does that — checklist provided); combat wiring of `GunDamageMul` (stub, like crew skills).
