# Job #082 - Final summary

**River jump ramps - Job 019's proven launch promoted onto the real river hooks.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

This was **promotion, not invention** - the physics already existed and was proven in Job 019, gated
behind `DEV_RAMPS = false` in a dev-only `RampTest`. Nothing about the launch was re-derived.

- **`RampServer.server.luau`** (new) - Job 019's launch on the real hooks. Mirrors `ObstacleServer`: one
  Heartbeat over a `Ramp` CollectionService tag, the same run/tied guards, angle read off the part.
- **`RiverBootstrap`** - the translucent green Neon slab replaced with a real ramp: an invisible trigger
  box carrying the angle, plus a visual (library `RiverRamp` if present, else a `WedgePart`). Three
  angles picked by z-noise: **12 / 22 / 32 degrees**.

Tuning inherited unchanged: `LAUNCH_BASE 40` - `+1.6/deg` - cap `95` - `FLIP_RATE 0.5` - `MIN_SPEED 6` -
`ARC_TIME 0.6` - debounce `2.5`. The "Ramp Bow & Hull Shape" module (Job 067, 170 Gold) multiplies it by
`1.35`.

## RAMPS ARE NON-COLLIDING AND MUST STAY THAT WAY

Job 019 measured it: a heavy, buoyant, level-controlled boat **cannot climb a solid ramp** - it jams
against the face and stalls. The boat drives THROUGH and the launch is applied directly. Making the ramp
collidable would not add realism, it would delete the feature.

## Verified in Play

- 4 ramp / 9 obstacle hooks over the first 6,000 studs (the ~2:1 split `RiverData` documents); the tag
  streams with its chunk.
- Sample ramp: 34 x 8 x 13, angle 32 degrees, `Transparency 1`, `CanCollide false`.
- **The jump fires:** driven at a 32-degree ramp the boat rose y 13.38 -> peak **35.58 (+22.2 studs)**,
  with `LaunchUntil` set. Predicted peak from the tuning was ~21, so the numbers hold.
- Console: `[Ramp] LAUNCH 32 - fwd 9.6 -> up 95.0 (boost x1.35)`.

## Outstanding

**Real ramp art (Meshy) - awaiting credit approval.** Ramps currently render as a `WedgePart` unless the
library has `RiverRamp`. Functionally complete; cosmetically a placeholder.
