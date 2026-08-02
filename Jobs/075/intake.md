# Job #075: In-game GUI restyle — three HUD states on the lobby design system

**Project**: `roblox.jungle`
**Created**: 2026-08-02 23:13:19
**Status**: Plan written — awaiting go-ahead. See [`implementation-plan.md`](implementation-plan.md).

## Requirements / goal

Restyle every game-place GUI onto the shared Theme/Components design system (already present in sync/ReplicatedStorage/UI, byte-identical to the lobby's, but only RobuxShop uses it). Organise the in-run interface into three context states driven by one controller: (A) CRASH SITE / before boarding, (B) ABOARD / riding the river, (C) ASHORE / dock excursion on foot. Top-right is currency chips only (Gold + Salvage) per STYLEGUIDE 6.11 - no avatar/level/XP block in-run. Also build: a themed player health bar replacing the Roblox core bar, a role/station indicator chip, a river progress bar with zone + next-dock markers, and custom mobile touch throttle/steer controls for the boat. Reference mockup: assets/Images/GUI_PATTERN.png. Promotes Planned/P7-hud-scoring-leaderboards.md and Planned/mobile-boat-controls.md.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created — [`implementation-plan.md`](implementation-plan.md)
- [ ] Plan agreed (awaiting go-ahead)
- [ ] Implementation completed
- [ ] Final summary + changelog written
