# Job #040: Fix: carry riders with the moving boat (no deck slide)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 17:52:08
**Status**: Requirements Gathering (intake)

## Requirements / goal

Fix FINDING 0000. Standing (unseated) players slide on the boat because a client-owned character on a server-owned MOVING boat isn't carried smoothly. Fix CLIENT-SIDE (don't touch the fragile server boat physics / ownership): a LocalScript each RenderStepped detects if the local character is standing on the boat (raycast down → a boat part) and NOT seated, then applies the boat hull's per-frame transform delta to the character's HumanoidRootPart, carrying them with the boat (position + yaw) while still letting them walk. Skips seated players (seat already carries them). Verify no jitter + walking still works.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
