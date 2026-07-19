# Final Summary — Job #058: Solo tuning pass (scale threat by crew size)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Implements the GAME.md
"soloable but harder" decision (todo 0000). Game place.

## What
A lone player can't man two stations at once (drive AND gun), so a full enemy load makes solo unwinnable.
Threat now scales with crew size: **0.55× at 1 player → 1.0× at 6** (linear). Solo is finishable; a full crew
faces the full challenge. No player/boat buffs — it stays *harder*, not *assisted*.

## Implementation
- **`EnemyServer`**: `crewScale()` (0.55 → 1.0 by player count) multiplies `seaCap()` and `landCap()` (min 1),
  after the distance ramp + night bonus.
- **`ExcursionServer`**: the same scale multiplies the escalating camp guard counts (near/deep, min 1), so a
  lone raider can still clear a camp.

## Verified (live in Studio — 1 player)
- [x] Analyzer-clean.
- [x] River enemies capped at **sea 2 / land 1** near the start (was ~4 / 3 unscaled) — ~0.55×.
- [x] First-landing camp guards **2** (was 3 unscaled).
- [~] Crew-of-6 = full caps by the linear formula (can't spawn 6 players in Studio solo to measure; math
      reaches 1.0× at 6).

## Notes / follow-ups
- **Not committed.**
- `SOLO_SCALE` (0.55) and the 6-player full point are tunable; expect a live playtest to refine the solo feel.
- No solo revive safety net was added — going down solo still means bleed-out (paid self-revive is the P8
  net). The lighter enemy load is the accommodation; revisit if solo deaths feel too punishing.
- This completes the last GAME.md decision follow-up (Medic role + solo tuning both done).
