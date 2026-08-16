# Job #081 - Final summary

**Boat wake VFX + the three unwired boat sounds.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

**`BoatWake.local.luau`** (new) - client-side, mirroring `BoatSound`'s `attach(boat)` + generation-guard
pattern. Five instances on the hull, all scaled by speed:

- bow spray x2 at the forward corners, angled outward and back (16/s each at full speed)
- prop wash behind the `Motor` (26/s at full speed)
- two stern `Trail`s, `Lifetime` 0.7 -> 2.2 with speed

**`BoatSound.local.luau`** - the three owned-but-never-wired ids hooked onto the existing `HP` listener
(one hook already covered enemy bites and obstacles, so nothing else needed editing):
`metal_debris` layered on a hit >=18% of MaxHP - `boat_on_fire` looping under 30% hull -
`boat_destroyed` one-shot at 0.

## Verified by measurement

- Analyzer exit 0; all five instances build on the hull.
- **At rest:** every emitter `Rate = 0`, both trails disabled - a moored boat emits nothing.
- **At 24 studs/s:** bow 12.5/s each, wash 20.3/s, both trails on, `Lifetime` 1.87.
- All seven wake attachments pin to the waterline at exactly **y = 12.00** as the hull bobs.

Geometry these numbers are tuned against: hull **14 x 3 x 32**, centre y 13.38, `WATER_Y` 12.0 (~0.12
studs wetted), **forward is -Z**.

## WARNING: still not signed off

**No clean sustained visual.** Driving in Studio kept beaching the boat on the river's meander, so the
wake has never been watched at speed on open water for more than a moment. The rates and attachment
heights are measured; how it *reads* is not. A human still needs to confirm it.
