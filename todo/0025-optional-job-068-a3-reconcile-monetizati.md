# TODO 0025: OPTIONAL (Job 068 A3): Reconcile MonetizationDefs robux prices against the Creator Hub

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — Done in Job 069, 2026-08-02. FIRST, the snapshot: all 8 ids verified live via GetProductInfo and ALL 8 MATCH -- gold packs 49/99/199/449, Self Revive 20, Armored Boat 499, Boat Paint 99, Extra Slots 149. Nothing was mispriced. SECOND, the mechanism, which is why this todo existed: the three passes use MANAGED PRICING, so Roblox can move a price without touching our code and nothing would tell us. RobuxShop now fetches the real price per row via GetProductInfo(...).PriceInRobux and falls back to MonetizationDefs.robux when the call fails. Deliberately NON-BLOCKING: the panel builds and opens on the def price immediately and each row corrects itself when its own lookup lands, because a web call must never gate the UI. Cached per session. RACE HANDLED: the price fetch re-runs the same refresh() the ownership listener uses, never setText directly -- both are async, and if a late price wrote the button itself it could overwrite OWNED on a pass the player already has, turning a settled row back into a buy button. VERIFIED in Play: all 8 rows print correct prices, and the three owned passes still resolve to OWNED/Active=false once ownership lands. Analyzer clean.
**Created:** 2026-08-02 10:50:56

Audit Job 068, gap A3. The robux field in MonetizationDefs is what the shop row PRINTS; the Hub is what the player is CHARGED. Nothing reconciles them, and Extra Inventory Slots has managed pricing enabled. A mismatch shows a wrong price, not a wrong charge. One-time GetProductInfo reconciliation pass; cheap, low risk.

## Half done — PASSES verified 2026-08-02 (user's Creator Hub screenshot)

All three live passes match `MonetizationDefs.GamePasses` exactly, so the shop prints the true price:

| Pass | Pass ID | Hub price | `MonetizationDefs.robux` | |
|---|---|---|---|---|
| Extra Inventory Slots | `1935044952` | 149 | 149 | ✅ |
| Boat Paint Pack | `1919355255` | 99 | 99 | ✅ |
| Armored Boat | `1919001295` | 499 | 499 | ✅ |
| ~~Cosmetic Bundle~~ | `1918077339` | **Offsale** | *(removed in Job 067)* | ✅ correctly gone |

**All three have Managed pricing ENABLED**, which is precisely why this todo should stay open rather
than close here: Roblox can move a managed price without touching our code, so today's match is a
snapshot, not a guarantee. The lasting fix is to stop hardcoding the number — read it from
`GetProductInfo(...).PriceInRobux` and let `robux` be a fallback for when the call fails.

**Still unverified — the DEVELOPER PRODUCTS** (a different Hub page, not in the screenshot):
`pack10` 49 · `pack25` 99 · `pack60` 199 · `pack150` 449 · `selfRevive` 20.
