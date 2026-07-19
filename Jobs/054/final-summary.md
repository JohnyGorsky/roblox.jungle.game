# Final Summary — Job #054: Pacing & optional stops (fuel/leg tuning + next-fuel HUD)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#6 of 6
(FINAL)** (`Planned/river-journey-overhaul.md`). Game place. (User feedback #5.)

## What
Makes fuel the pacing pressure and stopping a real, *informed* risk/reward choice: more frequent stops, enough
gasoline that skipping one is viable, and a HUD readout so you can see whether you'll make the next fuel.

## Implementation
- **More stops** — `RiverData.DOCK_SPACING` 2200→1600, so docks are closer and **landings (gasoline) fall every
  3200 studs** (verified at 1600 / 4800 / 8000) instead of 4400.
- **Fund the skip** — `ExcursionServer` near camp now drops **2 Gasoline crates** (was 1). With 1 gas = +40
  fuel (CargoServer) and a tank of 100 (~3600-stud full-throttle range), a topped tank + a gas haul reaches
  ~1.5 landings → you can skip one stop but not two.
- **Informed decision** — `HudClient` adds a **NEXT FUEL** readout: distance to the next landing ahead,
  **green** when your fuel range can reach it, **red** when it can't (conserve/drift or be stranded). Recomputes
  the landing every 0.5s; distance updates each frame; shown only during a run.

## Verified (live in Studio — game place)
- [x] Analyzer-clean (all touched files, both trees).
- [x] Landings at 1600 / 4800 / 8000 (every 3200); first landing built with **2 gasoline crates**.
- [x] HUD: at full tank "NEXT FUEL 1560 studs" in **green**; at Fuel=10 the same distance turns **red** (can't
      reach → warning).

## Notes / follow-ups
- **Not committed.**
- Numbers are tunable (`DOCK_SPACING`, `MAX_FUEL`/burn in BoatServer, `FUEL_PER_GAS` in CargoServer, gasoline
  crate count, `STUDS_PER_FUEL` estimate in HudClient) — expect playtest tuning of the "skip one, not two" feel.
- The natural cost of stopping is **time/night** (day/night cycle) + threat exposure; the fuel readout is the
  planning tool. A dedicated time/night-pressure pass could deepen it later.
- **This completes the river journey overhaul (all 6 items).**
