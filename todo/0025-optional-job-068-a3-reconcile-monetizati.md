# TODO 0025: OPTIONAL (Job 068 A3): Reconcile MonetizationDefs robux prices against the Creator Hub

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:56

Audit Job 068, gap A3. The robux field in MonetizationDefs is what the shop row PRINTS; the Hub is what the player is CHARGED. Nothing reconciles them, and Extra Inventory Slots has managed pricing enabled. A mismatch shows a wrong price, not a wrong charge. One-time GetProductInfo reconciliation pass; cheap, low risk.
