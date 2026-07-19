# Job #034: Role-station efficiency bonuses

**Project**: `roblox.jungle`
**Created**: 2026-07-19 16:19:29
**Status**: Requirements Gathering (intake)

## Requirements / goal

GAME.md P2 pillar: manning a station gives an efficiency bonus so dividing the crew matters. For POC: the four specialist stations (Driver seat, Gun seat, Fuel station, Repair station) grant a bonus while manned (e.g. driver +handling, gunner +fire/accuracy, refueller +fuel-per-gas AND lower burn, repairer +HP-per-metal). Optionally a lightweight role pick. Server-authoritative; stack sensibly with the per-player skills (Job 024/029).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline)
- [x] Implementation completed — presence-based station bonuses (driver/engineer/repairer/gunner) verified
      live (StationTurnMul 1.15, StationFuelMul 0.7, +2.5 HP/s regen); analyzer-clean
- [x] Final summary + changelog written
