# Final Summary — Job #055: Hide in-game HUD during the plane intro (todo 0010)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Fixes todo 0010. Game place.

## What
The objective banner + fuel/boat/cargo bars + hotbar + gold/salvage no longer show while you fly in on the
plane — they appear only when you WAKE UP at the crash site.

## Implementation
- **`sync/StarterPlayer/StarterPlayerScripts/UI/IntroHudGate.local.luau`** (new): a LATE `BindToRenderStep`
  (`RenderPriority.Last`) that, while `Workspace.IntroActive == true`, force-hides the persistent HUD
  ScreenGuis (`BoatHud`, `GoldHud`, `InventoryHud`, `StagingHint` objective banner, `RunGui`, `UntieButton`)
  each frame — so it wins over any script that re-enables them (no flicker) — and toggles core GUI
  (Backpack/Health) off. On the intro→done transition (wake-up) it restores them once. Inert if `IntroActive`
  is never set (standalone).

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] During a held intro (`IntroActive=true`): BoatHud/GoldHud/InventoryHud/StagingHint/RunGui all
      `Enabled=false`.
- [x] After the intro completes (wake): all restored to `Enabled=true`.

## Notes
- **Not committed.** Transient/contextual GUIs (ZoneBanner, DockShop, RobuxShop, AdminPanel, EnemyHealthBars)
  are left alone — they only appear contextually and not during the intro.
