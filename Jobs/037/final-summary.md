# Final Summary — Job #037: Lights (boat searchlight + carryable player torch)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0005. Game-only.

## What was built
- **Player Torch** (Dead Rails-style): a new inventory item that emits light while held, so night jungle
  excursions aren't blind. Kind `"Light"`; in the starting loadout (slot 2 — lootable later). Equipping it
  builds a glowing Neon held part + a **PointLight** (range 30, brightness 3, warm).
- **Boat searchlight**: confirmed the Searchlight module's `SpotLight` (from #025) lights forward — no change
  needed.

### Files
- **Edit:** `ReplicatedStorage/Inventory/ItemDefs.luau` — `kind` union +`"Light"`; `lightRange`/
  `lightBrightness` fields; **Torch** item.
- **Edit:** `ServerStorage/Inventory/InventoryService.luau` — seed slot 2 = Torch; `updateHeldVisual` adds a
  Neon part + PointLight for `"Light"` items.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] `Slot2 = Torch` seeded; hotbar shows "Torch".
- [x] Equipping (via `InventoryCmd`) → `ActiveItem=Torch`, held visual built with a **PointLight (range 30,
      brightness 3)**; the glowing torch is visible in-hand (screenshot).
- [~] Full night darkness didn't render in the screenshot (the server DayNight clock overwrote a client-side
      night override) — the torch's light is confirmed functionally (PointLight) rather than in a dark scene.
- Boat searchlight `SpotLight` presence confirmed earlier (#025).

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Torch is a starting item for POC; make it **lootable** at camps (a Torch crate) later, per the "find a
  torch" vision. Guns/melee ignore it (kind check) — it's passive light only.
- Could later: torch fuel/burnout, only-emit-at-night, a flame VFX, and tie the boat searchlight to Night
  Watch. Pairs with the queued **glowing-eyes (0008)** todo for the night-visibility theme.
