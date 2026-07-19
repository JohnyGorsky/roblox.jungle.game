# Final Summary — Job #048: Per-zone river current

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#2 of 6**
(`Planned/river-journey-overhaul.md`). Game place.

## What
The downstream current now varies by zone, using the `currentMul` data added to `ZONE_PROFILE` in #047. The
Rapids sweep the boat along faster; the Lost Delta slows it; Headwaters/Croc are normal.

## Implementation (`sync/ServerScriptService/Boat/BoatServer.server.luau`)
One line: `current.Force = downstream(pos.Z) * (CURRENT * RiverData.currentMulAt(pos.Z))` (was `* CURRENT`).
`currentMulAt` reads the shared per-zone profile, so terrain shape and flow stay in one source.

Multipliers: Headwaters 1.0 · Croc 1.0 · **Rapids 1.5** · **Delta 0.8**.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] At the boat's live start position (Headwaters, mul 1.0): `Current.Force = 11999` ≈ expected 12000 — the
      multiplier flows through end-to-end at the boat's actual `pos.Z`.
- [x] Per-zone resolved forces: Headwaters 12000 · Croc 12000 · **Rapids 18000 (×1.5)** · **Delta 9600 (×0.8)**
      — so idle drift (≈ force/DRAG) will be ~1.5× faster in the Rapids, ~0.8× in the Delta.

## Notes / follow-ups
- **Not committed.**
- Only the CURRENT (drift) force scales — thrust/steering are unchanged, so faster Rapids = harder to hold a
  line against the push (intended). Tune the 1.5/0.8 in `ZONE_PROFILE` if the Rapids feel too strong.
- Didn't drive the full 9000+ studs to the Rapids in-engine; the force is verified by the exact formula match
  at the live position + the per-zone `currentMulAt` values.
- Next in the overhaul: **#3 forks + small islands** (the heaviest piece).
