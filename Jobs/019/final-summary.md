# Final Summary — Job #019: Boat length trim + ramp-jump proof

**Project**: `roblox.jungle` (repo `roblox.jungle.game`)
**Completed**: 2026-07-19
**Status**: ✅ Both goals done and **verified live in Studio via telemetry logs**.

## Goal (1) — Boat too LONG (not tall)

The hull length made it impossible to see the stern while driving. Trimmed
`HULL_SIZE` in `BoatServer.server.luau` from `Vector3.new(14, 3, 22)`'s prior length **28 → 22**
(kept height 3, width 14). Still floats, drives, and stays stable (buoyancy/leveling unchanged).

## Goal (2) — Prove the POC assumption: can the boat JUMP off ramps?

**Answer: yes, proven with real telemetry.**

A heavy, buoyant, level-controlled boat **cannot physically climb a solid ramp** (earlier attempts
jammed/stalled — a thick ramp edge is a wall, and the leveling constraint fights the incline). So the
proven approach is a **non-colliding jump-pad trigger**:

### `World/RampTest.server.luau` (new, DEV/TEST — `DEV_RAMPS` flag)
- Builds 3 translucent Neon **WedgePart** pads at 10° / 20° / 35° down the channel, `CanCollide = false`
  (drive *through* them — no jam), each with a `"N° JUMP"` billboard.
- Heartbeat watches the boat hull: when it's inside a pad's footprint moving forward faster than
  `MIN_SPEED (6)`, it **applies the launch directly**:
  - **Linear:** keep horizontal velocity, set upward `launchUp = min(40 + angle·1.6, 95)` studs/s.
  - **Angular:** a *gentle* nose-**up** `-RightVector · 0.5` rad/s (not a somersault).
  - Sets `boat.LaunchUntil = clock + ARC_TIME(0.6)` and logs `[RampTest] LAUNCH …`.

### `Boat/BoatServer.server.luau` (edit)
- While `os.clock() < boat.LaunchUntil`, buoyancy force and attitude leveling are **suspended** (torque
  0) so they don't fight the arc; after the window, leveling resumes and **catches the landing**.
- Added a throttled `[BoatDBG]` state log (spd/fwd/Y/velY/launched/thr, every 0.25s while `RunStarted`).

### Tuning history (why the final numbers)
First pass (`flip = 1.6 rad/s`, `arc = 1.3s`) jumped fine but the flip was a full **~119° nose-over**:
the boat tumbled, landed **backward**, punched **underwater** (Y = −1.3, water = 12), got stuck, and was
destroyed. Fix: flip **1.6 → 0.5**, direction reversed to nose-**up**, arc **1.3 → 0.6** so buoyancy
re-engages during the descent and decelerates the fall.

## Verified (live in Studio, Game place — telemetry, new code `flip=0.5`)
Peak air and landing behaviour off each pad:

| Ramp | Air (peak Y − rest 14.6) | After apex | Lowest Y (water 12) | Recovery |
|------|--------------------------|------------|---------------------|----------|
| 10°  | ~8 studs                 | stays fwd  | 10.8                | ~1s to cruise |
| 20°  | ~13 studs                | stays fwd  | 14.1                | ~1s to cruise |
| 35°  | ~22 studs                | stays fwd  | 13.9 (never under)  | ~1.5s to cruise |

- [x] Boat jumps off all three ramps (clear airborne arc in `Y`/`velY`).
- [x] No backward tumble — `fwd` stays positive through the arc.
- [x] No underwater plunge — min landing Y ≥ 13.9 (was −1.3 on the old flip).
- [x] Recovers to cruise speed (`fwd ≈ 35`) within ~1–1.5s; boat survives (no DESTROYED).

## Files
- **Edit:** `sync/ServerScriptService/Boat/BoatServer.server.luau` (length 28→22; LaunchUntil
  suspend/resume; `[BoatDBG]` log).
- **New:** `sync/ServerScriptService/World/RampTest.server.luau` (DEV jump-pads + launch loop).
- New: `Jobs/019/*`.

## Left in place intentionally (per user — "tune later with real ramps")
- `DEV_RAMPS = true` and the `[BoatDBG]`/`[RampTest]` logs are **still on** so the jump can be tuned
  when real ramp obstacles are designed. **To disable:** set `DEV_RAMPS = false` in
  `RampTest.server.luau`; remove/guard the `[BoatDBG]` print in `BoatServer` when done.

## Notes / follow-ups
- **Not committed.**
- The 35° arc is still a bit violent (steep drop, velY ≈ −78) but stable — acceptable for POC; tune
  `LAUNCH_*` / `FLIP_RATE` / `ARC_TIME` when real ramps land.
- Ramp jumps become a real obstacle feature later (level design), not a dev pad.
