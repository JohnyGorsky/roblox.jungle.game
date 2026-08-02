# TODO 0016: Grant purchasable inventory slots + cosmetic visuals

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — Superseded by Job 067, confirmed by the Job 068 lobby audit. All three halves are now real: (1) Extra inventory slots -- the pass exists (1935044952, 149 R$) and sync/ReplicatedStorage/Inventory/ItemDefs.slotsFor reads Owns_extraSlots to raise the loadout 4 -> 6. (2) Boat Paint applies real visuals -- BoatPaint + PaintServer + PaintShop, 6 hull liveries, and the moored showroom boat repaints instantly. (3) Cosmetic Bundle is no longer ownership-only because it is no longer sold -- Job 067 removed it from MonetizationDefs (it delivered nothing). The one remaining scrap is the manual Creator Hub unlisting, which now has its own todo 0020.
**Created:** 2026-07-19 23:07:00

Make the monetization perks actually apply: extra inventory slots add real slots; Boat Paint / Cosmetic Bundle apply real visuals (currently ownership-only).
