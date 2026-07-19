# Final Summary — Job #027: Robux monetization (Gold packs + Armored Boat + cosmetics)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §6.
Depends on #021/#022/#025.

## What was built
- **Gold packs** (developer products): 10/25/60/150 Gold → `ProcessReceipt` grants Gold **idempotently**
  (records `PurchaseId` in the profile) and persists immediately.
- **Armored Boat** (game pass, the one power item): if any crew member owns it, the boat gets **+20% hull
  HP** and **`GunDamageMul=1.2`** (mounted-gun damage — combat reads it later) + visible armor plating.
- **Cosmetics** (game passes): Boat Paint Pack, Cosmetic Bundle — ownership tracked (`Owns_<key>` attr);
  visuals are a later pass (no cosmetic system yet).
- **Robux shop UI** (lobby): Gold packs (`PromptProductPurchase`) + passes (`PromptGamePassPurchase`);
  unset products show "Soon".

### Files
- **New (both trees):** `ReplicatedStorage/Progression/MonetizationDefs.luau` (catalog + `goldForProduct`);
  `ServerScriptService/Progression/MonetizationServer.server.luau` (`ProcessReceipt` + pass ownership).
- **Edit (both trees):** `ProfileConfig.luau` — `purchaseIds = {}` (idempotency).
- **New (lobby):** `StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau`.
- **Edit (game):** `Boat/BoatModules.server.luau` — Armored Boat effect.

## Verified (Studio — partial by nature)
- [x] Analyzer-clean (both trees).
- [x] **Armored Boat:** owner + run start → `MaxHP 100→120`, `GunDamageMul=1.2`, plating present.
- [x] **Receipt mapping/idempotency:** unset IDs ignored; correct product→Gold (pack60→60); unknown not
      consumed; a repeat `PurchaseId` is not re-granted.
- [x] **Shop UI:** Gold packs + passes render; all "Soon" while IDs are 0 (screenshot).
- [~] **Real Robux prompts + receipts** — cannot be exercised in Studio; **verify on a published place**
      after creating the products and pasting IDs.

---

## 🛒 HUMAN STEP — create these on the Roblox Creator Dashboard, then paste the IDs

Create under the **experience** (universe 10520080584). **Developer Products:** Dashboard → your experience →
**Monetization → Developer Products → Create**. **Game Passes:** **Monetization → Passes → Create**
(attach to the Lobby place is fine — ownership is checked experience-wide).

### Developer Products (Gold packs) → `MonetizationDefs.GoldPacks[n].productId`
| Name | Type | Price (R$) | Description (paste) | Code field |
|------|------|-----------:|---------------------|-----------|
| 10 Gold | Developer Product | 49 | "Adds 10 Gold to your account." | `GoldPacks[1].productId` |
| 25 Gold | Developer Product | 99 | "Adds 25 Gold to your account." | `GoldPacks[2].productId` |
| 60 Gold | Developer Product | 199 | "Adds 60 Gold to your account — best value." | `GoldPacks[3].productId` |
| 150 Gold | Developer Product | 449 | "Adds 150 Gold to your account." | `GoldPacks[4].productId` |

### Game Passes → `MonetizationDefs.GamePasses[n].gamePassId`
| Name | Type | Price (R$) | Description (paste) | Code field |
|------|------|-----------:|---------------------|-----------|
| Armored Boat | Game Pass | 499 | "A reinforced premium boat: +20% hull HP and +20% mounted-weapon damage. Stacks with your upgrades." | `GamePasses[1].gamePassId` (armoredBoat) |
| Boat Paint Pack | Game Pass | 99 | "Unlock extra hull colour skins for your boat." | `GamePasses[2].gamePassId` (boatPaint) |
| Cosmetic Bundle | Game Pass | 249 | "Cosmetic trails, engine-wake FX, and an emote." | `GamePasses[3].gamePassId` (cosmeticBundle) |

**After creating each:** copy its numeric ID into the matching field in **both** `sync/` and `lobby/sync/`
`ReplicatedStorage/Progression/MonetizationDefs.luau` (keep the two copies identical), publish, and live-test
a purchase (Studio can't). Each product also wants an **icon image** (optional but recommended).

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- `GunDamageMul` is a stub attribute — wire it into the mounted-gun damage calc when polishing combat.
- Cosmetic visuals (paint/trails/FX) not applied yet — ownership is tracked.
- Robustness for real money: consider swapping the simplified profile service for community **ProfileStore**
  before launch (receipt grant currently persists via `Profiles.save`; ProfileStore adds stronger guarantees).
- **This completes all 8 POC economy/monetization jobs (#021–#028).**
