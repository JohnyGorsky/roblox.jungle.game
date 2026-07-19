# Final Summary — Job #047: Zone-driven river shape + turn variety

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#1 of 6**
(`Planned/river-journey-overhaul.md`). Game place. Greybox.

## What
The seeded river now changes **character per zone** instead of looking the same throughout, and the meander is
more varied (fixes "straight & predictable"). The Rapids actually narrows/twists/gets dense; the Lost Delta
opens wide; Headwaters is a calm ease-in. Continuous functions of distance → no seams, aligned to ZoneServer's
4 zones.

## Implementation (`sync/ReplicatedStorage/River/RiverData.luau`)
- **`ZONE_PROFILE`** — per-zone anchors (width / turn / obstacle-density / currentMul) keyed at each zone's
  center as a fraction of `END_DISTANCE`, linearly interpolated → continuous `RiverData.profileAt(z)`.
- **`centerlineX`** — now 3 Perlin octaves: big course bend (always on) + medium bends + fine detail, with the
  medium+fine octaves **scaled by the zone's `turn`** so Rapids snakes and Headwaters stays lazy.
- **`widthAt`** — per-zone base width + gentle noise, clamped 80–330 (Rapids ~110 tight, Delta ~300 wide).
- **`hooksBetween`** — dense candidate grid (120) thinned per zone by `obs` density (deterministic keep-roll).
- **`currentMulAt(z)`** added (data ready; wired into BoatServer in overhaul **#2**, not this job).
- **`RiverGenerator.luau`**: `MAX_HALFW` 140→170 so the chunk region covers the wide Delta.

## Tuning note
First pass used Rapids `turn=1.85` / width 95 — too sharp for a narrow channel (centerline shifted more than
the half-width over the boat's length → undrivable hairpins). Verified numerically and dialed to `turn=1.35`
/ width 110: centerline shifts ~40 studs over the boat's 22-length, inside the 55 half-width — twisty but
drivable.

## Verified (live in Studio)
- [x] Analyzer-clean (river is game-only; no lobby copy).
- [x] Profile math: Headwaters w150/turn0.70/obs0.60 · Croc w201/1.00/1.00 · **Rapids w106/1.35/1.90** ·
      Delta w300/0.85/1.00; centerline "swing" over 600 studs Rapids 421 vs Delta 86; obstacle density
      1→9 per 1000 studs Headwaters→Rapids.
- [x] Channel **continuous**: 28/28 centerline slices in the Rapids have Water (a tube around a continuous
      curve can't disconnect — the top-down "diamond" look is a terrain-water *render* artifact at altitude,
      not a real gap; boat-eye and angled views render as a normal winding river).
- [x] Play: boat spawns floating on water (Y=13.4), start width 150, 512 water voxels around it; start river
      renders as a winding channel with tree banks + grass→rock→snow hills.

## Notes / follow-ups
- **Not committed.**
- Numbers are tunable in `ZONE_PROFILE`; easy to push the Rapids tighter later if the boat handles it.
- Next in the overhaul: **#2 per-zone current** (wire `currentMulAt` into BoatServer — Rapids fast, Delta slow).
- The high-altitude top-down water render artifact is cosmetic (not seen at gameplay angles); revisit only if a
  fly-over ever frames a twisty zone from directly above.
