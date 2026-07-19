# Final Summary — Job #038: Night-only lights + hotbar deselect toggle

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Game-only.

## What was built
1. **Lights on at night only** — the player torch (PointLight) and boat searchlight (SpotLight) are OFF by
   day and ON at night, driven by the day/night `Phase`.
2. **Deselect toggle** — re-clicking the already-active hotbar slot puts the item away (empty hands).

### Files
- **New:** `World/LightController.server.luau` — any `Light` tagged `"NightLight"` → `Enabled = (Phase ==
  "night")`; toggles on the Phase flip + for newly-created tagged lights.
- **Edit:** `ServerStorage/Inventory/InventoryService.luau` — torch PointLight now `Enabled=false` +
  tagged `NightLight`; `equip(slot)` **toggles off** when you re-click the active slot (ActiveSlot→0 →
  ActiveItem "" → held visual cleared).
- **Edit:** `Boat/BoatModules.server.luau` — searchlight SpotLight `Enabled=false` + tagged `NightLight`.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Torch light `Enabled=false` by day; tagged `NightLight`; setting `Phase="night"` → controller turned
      it **ON**.
- [x] Deselect: re-click active slot → **HeldItem removed** (torch put away); re-click again → re-equipped.
- Boat searchlight uses the same tag/controller → same day/night behavior (construction-verified).

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- "Dusk" = the `night` phase (ClockTime ≥ 19). If you want lights to fade in a bit earlier/gradually, we can
  add a dusk window or tween brightness.
- Deselect sets `ActiveSlot=0` (no valid slot) → unarmed; the Sword remains the fallback you can always re-select.
