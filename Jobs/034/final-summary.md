# Final Summary — Job #034: Role-station efficiency bonuses

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · GAME.md P2. Game-only.

## What was built
Presence-based **station bonuses**: while a station is manned it works better, so dividing the crew pays off
(pulling someone off a station has a real cost). These are continuous, distinct from the per-player skills
(they stack).

| Station | Manned by | Bonus |
|---|---|---|
| Driver seat | seated driver | +15% handling (`StationTurnMul` 1.15) |
| Fuel Station | engineer within 11 studs | −30% fuel burn (`StationFuelMul` 0.7) |
| Repair Station | repairer within 11 studs | passive hull regen (+2.5 HP/s) |
| Gun seat | seated gunner | faster turret (`StationGunMul` 0.85 fire interval) |

### Files
- **New:** `Boat/RoleServer.server.luau` — per-tick presence/seat checks → sets the station attributes +
  applies the repair regen.
- **Edit:** `Boat/BoatServer.server.luau` — fuel burn `× StationFuelMul`, turn `× StationTurnMul`.
- **Edit:** `Combat/GunServer.server.luau` — turret fire interval `× StationGunMul`.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Driver seated → `StationTurnMul=1.15`.
- [x] Engineer at fuel station (dist 1.5) → `StationFuelMul=0.7`.
- [x] Repairer at repair station → **HP 50→55 over 2s** (regen).
- [~] Gunner turret bonus — construction-verified (same seat-occupancy path as the verified driver bonus).
- Testing note: placing the client-owned character at a station required disabling the VehicleSeat + anchoring
  the (drifting) hull — the seat kept re-grabbing and the moving boat carried the welded stations away.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- These stack multiplicatively with the per-player skills (Diesel/Rudder/GunDiscipline) and modules.
- No explicit "role assignment" (presence-based for POC); a lightweight role pick could layer on later.
- Next in the deepen-the-run set: **#035 zones + day/night stakes**.
