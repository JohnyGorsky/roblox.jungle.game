# TODO 0048: Drop hint text overlaps the health bar

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 22:14:40

Reported 2026-08-16 playtest (screenshot): 'TAP OR [G] TO DROP' is drawn on top of the HEALTH 100 bar, making both hard to read.

ROOT CAUSE (verified): sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau:124 -- dropHint.Position = UDim2.fromScale(0.5, 1.05) with AnchorPoint (0.5, 0). It hangs the hint BELOW the HANDS FULL card, and the health row sits exactly there, so the two occupy the same band. Job #084 already moved the HANDS FULL card itself off the first hotbar slot (see the file header comment at :15) but the hint that was added under it was never given its own space.

Note the drop hint has no explicit ZIndex while its sibling dropBtn is ZIndex 5, so the stacking is incidental rather than chosen.

FIX DIRECTION (not decided): either put the hint INSIDE the card (it is already a button -- the card is the drop target per the Job #084 comment at :99) or reserve a row for it so the health bar is never underneath. Must stay mobile-first / scale-based per the jungle-project rules.
