# Job #107: Trading post uses the RobuxShop kiosk + admin TP lands in a rendered camp

**Project**: `roblox.jungle`
**Created**: 2026-08-23 19:40:40
**Status**: Requirements Gathering (intake)

## Requirements / goal

TWO PARTS. (1) The village trading post building becomes the lobby/crash-site RobuxShop kiosk (AssetLibrary.Structures.RobuxShop, 24.5x21.3x19.4, 6 parts) instead of BahayKubo7 (40.2x25.8x50.2, 95 parts), so the TRADING POST sign and the shop stand together. NO other camp building changes - hut, hutAlt and tent are untouched. (2) The admin panel's existing 'TP to First Camp' must land the admin in a camp that is actually built and rendered: today ForceFirstCamp fails from the spawn base because RiverBootstrap only generates ~1800 studs ahead of the boat and the first landing is at z=1600, and even if built, the terrain under it is culled outside the boat's window.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
