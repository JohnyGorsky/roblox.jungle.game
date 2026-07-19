# Job #055: Hide in-game HUD during the plane intro (todo 0010)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 21:53:21
**Status**: Requirements Gathering (intake)

## Requirements / goal

From todo 0010. New IntroHudGate.local (StarterPlayerScripts/UI): while Workspace.IntroActive==true, force-hide the persistent in-run HUD ScreenGuis (BoatHud, GoldHud, InventoryHud, StagingHint objective banner, RunGui, UntieButton) + core GUI (Backpack/Health) each frame via a late BindToRenderStep (overrides any re-enabling, no flicker); on the intro->done transition (wake-up) restore them once. Inert if IntroActive is never set. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
