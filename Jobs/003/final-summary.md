# Final Summary — Job #003: P1 boat + winding-river vertical slice (greybox)

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed — core question answered ("driving the boat feels good")

## What was implemented

A playable greybox that proves the P1 question: **does driving the boat down the winding river feel
good?** — signed off by the user after live drive-tests. Placeholder block boat, real river feel.

- **Boat controller** (`sync/ServerScriptService/Boat/BoatServer.server.luau`) — builds a placeholder
  hull at the river start and drives it with real forces, **server-authoritative**:
  - **Buoyancy** — spring-damper targeting the true water surface, cooperating with terrain-water
    buoyancy (not fighting it) → planted float, minimal bob.
  - **Thrust / Current / Drag** — throttle drives forward; the current carries you downstream along
    the channel; drag gives a finite top speed (`THRUST/DRAG`). Speed is a single knob (`THRUST`) —
    the natural hook for a future boat-speed upgrade.
  - **Rudder steering** — one `AlignOrientation` drives the whole hull attitude: heading turn-rate
    scales with forward speed (must be moving to steer; momentum drifts you through bends), **banks
    into the turn**, and **trims the bow up under throttle / down when braking**. No tank-spin-in-place.
  - **Server ownership** — re-asserts `SetNetworkOwner(nil)` on sit so the loop reads un-lagged state
    and stays exploit-resistant for co-op.
- **Chase camera** (`sync/StarterPlayer/StarterPlayerScripts/Boat/BoatCamera.local.luau`) — activates
  only while seated in the boat's `DriverSeat`; follows behind+above with velocity look-ahead,
  collision pull-in, a decaying-shake hook, and an eased **speed-based FOV** swell. Restores the
  default camera on dismount. Runs at `RenderPriority.Camera` with frame-rate-independent smoothing.
- **River** — the winding sculpted voxel river + water (from spike #004) in the live place; the boat's
  centerline + waterline were **measured from the actual sculpt via voxel read-back** so it spawns in
  water and routes the bends.
- **Mobile controls** — `VehicleSeat` default touch controls (works on a phone); a custom scale-based
  on-screen UI was deferred (see follow-ups).

## How it was done

This job was originally built **before the shared skills existed**, then **reviewed against them**
(`roblox-physics`, `roblox-camera`, `roblox-scripting`) and corrected. The review caught: ambiguous
client/server ownership (jitter), a guessed centerline/waterline that spawned the boat on dry grass,
buoyancy fighting terrain water, and missing drag (unbounded speed). All fixed and re-verified.

## Verification (live / CLI)

- [x] `bash tools/luau-analyze.sh` clean on both scripts.
- [x] Play: boat spawns in water, floats planted (~Y 13.4), **pitch/roll 0** (no capsize), holds
      heading, current carries it downstream at the tuned ~6 studs/s.
- [x] Boat confirmed **server-owned** and routing the measured centerline through the bends.
- [x] User drive-tested the feel across several iterations (rudder, banking, bow trim, speed, FOV) →
      **"now it feels like a real boat."**

## Files changed (roblox.jungle)

- New (auto-sync): `sync/ServerScriptService/Boat/BoatServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatCamera.local.luau`.
- New: `Jobs/003/final-summary.md`, `Jobs/003/changelog.md`.
- Live place: sculpted river terrain + water (**not auto-synced — user saves the place** to persist).

## Notes / follow-ups

- **Not committed** (per the rule) — awaits user review + commit.
- **Feel is tunable later** — all knobs are commented (`THRUST`, `CURRENT`, `TURN`/`TURN_FULL_SPEED`,
  `MAX_BANK`, `MAX_PITCH`, `DRAG`; camera `FOV_*`).
- **Deferred to Planned:**
  - Custom on-screen **mobile touch controls** (scale-based steer/throttle) →
    `Planned/mobile-boat-controls.md`.
  - Reusable **seeded river+terrain generator** so the world regenerates each session instead of being
    baked into the place (spike #004's "Next") → `Planned/river-terrain-generator.md`.
- **Visuals/audio are P9** (splashes, spray, wake, engine/water sound, real boat model, lighting).
  Combat/roles/fuel/docks are P2–P4. This job is the permanent *mechanical* core they drop onto.
