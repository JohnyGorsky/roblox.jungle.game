# Job #052: Fix weak boat light + slide-off-seat on moving boat

**Project**: `roblox.jungle`
**Created**: 2026-07-19 20:22:01
**Status**: Requirements Gathering (intake)

## Requirements / goal

Two playtest bugs. 1) Boat night light too weak (can't see, worse now the moon's gone): boost the default bow SpotLight (range/brightness/angle) + add a local PointLight for deck/near visibility; boost the searchlight module too. 2) Exiting the driver seat while the boat is moving launches the player with the seat's inherited velocity, so they slide faster than the boat and off it: in BoatRideClient, on the seated->unseated transition zero the character's horizontal velocity so the per-frame carry keeps them on deck. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
