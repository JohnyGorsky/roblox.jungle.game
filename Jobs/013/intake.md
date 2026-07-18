# Job #013: P4: resource loop - trailer cargo, boat fuel/repair stations, ammo

**Project**: `roblox.jungle`
**Created**: 2026-07-18 18:22:45
**Status**: ✅ Completed (2026-07-18)

## Requirements / goal

Replace the pier auto-refuel with the real loot->store->use loop (GAME.md 'Cargo/trailer & stations'). Add a towed TRAILER behind the boat (roped, greybox raft, follows) holding cargo (Gasoline/Metal/Ammo counts + CargoMax capacity). Loot camps yield varied resources -> deposit into the trailer. On-boat FUEL station (spend 1 gasoline -> refuel tank) and REPAIR station (spend 1 metal -> restore hull HP). Weapon consumes AMMO from the trailer (auto-reload per ammo crate); out of ammo = can't shoot. Remove the dock Refuel prompt. Server-authoritative, greybox. Deferred: capacity gamepass slots, physics-tow trailer, fuel-can haul visuals, repair/refuel animations. Skills: roblox-physics (rope/tow), roblox-ui (prompts).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
