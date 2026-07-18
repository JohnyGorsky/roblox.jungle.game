# Final Summary — Job #010: Boat fuel, gauge HUD + refuel docks

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed & verified (greybox)

## What was implemented

The "reason to stop" pillar: fuel drains as you ride, and you must reach docks to refuel.

- **Boat fuel** (`BoatServer`) — `Fuel`/`MaxFuel` attributes; drains each frame (`FUEL_IDLE` +
  `FUEL_THROTTLE`·|throttle|). At **0 fuel the engine cuts** (throttle forced to 0) → you drift at the
  current's mercy = stranded.
- **HUD** (`StarterPlayerScripts/UI/HudClient`) — bottom-centre **FUEL** + **BOAT** bars, scale-based /
  mobile-first, colour-shift when low. Reads the Boat's replicated attributes. (Greybox; the real
  design system is P9.)
- **Docks** — `RiverData.docksBetween` places **seeded docks** every `DOCK_SPACING` (2200) on a bank;
  **`DockServer`** streams them near the boat (plank + red fuel drum + **Refuel** ProximityPrompt),
  culling ones left behind.
- **Refuel** — hold the dock's prompt; the **server checks the boat is actually beside the dock**
  (≤65 studs) then tops the tank to full. (Carry-fuel-cans + in-run cash come later.)

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all four scripts.
- [x] Fuel drains (idle 92.9 → 92.6 over 2 s); attributes replicate.
- [x] Dock streams in at its seeded spot (z=2200, within 2 studs) with a working `RefuelPrompt`.
- [x] Refuel is **position-gated**: refused at 108 studs (boat mid-channel), **fired at 27 studs**
      (pulled alongside) → Fuel 8 → 100.
- [x] HUD renders (FUEL + BOAT bars, screenshot) — plus the day/night cycle was seen flipped to **night**.

## Files changed (roblox.jungle)

- New: `sync/StarterPlayer/StarterPlayerScripts/UI/HudClient.local.luau`,
  `sync/ServerScriptService/World/DockServer.server.luau`.
- Edited: `sync/ServerScriptService/Boat/BoatServer.server.luau` (fuel drain + stranded),
  `sync/ReplicatedStorage/River/RiverData.luau` (`docksBetween`, `DOCK_SPACING`).
- New: `Jobs/010/*`.

## Notes / follow-ups

- **Not committed** (per the rule).
- The **hold-to-refuel** (2 s prompt) needs a **playtest** to confirm the interaction (server refill
  logic is verified). Same as the revive prompt.
- Tunables: `MAX_FUEL`/`FUEL_IDLE`/`FUEL_THROTTLE`, `DOCK_SPACING`, dock stream `AHEAD/BEHIND`,
  `REFUEL_RANGE`.
- **Next for P4:** carry-fuel-cans haul chore; **in-run cash + dock shop**; **threats spike while
  stopped** (ties P3 + day/night — docking at night is the gamble); then the **land-excursion raids**
  (docks → camps/villages, `Planned/land-excursions-camps-villages.md`).
- Minor: HUD sits above the VehicleSeat speed gauge now; a proper HUD layout is P9.
