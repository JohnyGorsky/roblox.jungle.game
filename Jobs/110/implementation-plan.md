# Job #110 — Implementation plan

**Project**: `roblox.jungle` · **Status**: done (copy delivered; user sculpted and built the endgame on it)

## Goal

Give the river a real destination by duplicating the hand-sculpted START landing basin
(`Workspace.SpawnBase` + its terrain) to the river's END at z = 18000, so the user has a working,
proven junction to re-sculpt rather than a blank void.

## The transform

Naive `+18000` in Z fails twice: the basin lands at z ∈ [17000, 18000] — *inside* the generated
corridor — and its mouth faces downstream, away from the arriving boat. Mirroring in Z fixes the
topology but is a reflection (negative determinant): signs read backwards, meshes turn inside out.

The move that works is a **180° rotation about the vertical axis through the junction**:

```
(x, y, z)  →  (−x, y, 18000 − z)        rigid, determinant +1, nothing mirrored
CFrame     =  CFrame.new(0, 0, 18000) * CFrame.Angles(0, math.pi, 0)
```

Mouth plane z=0 → z=18000 · basin body → z ∈ [18000, 18898] · mouth opens upstream at the boat.

## What was done

- **Terrain** — 1,337,251 voxels copied in 8 slabs at res 4, index-reversed on both the X and Z axes.
  Verified at 7 landmark points (channel centre, both mouth edges, three hillsides); every one matched
  its source exactly, water level included.
- **Objects** — `Workspace.SpawnBase` cloned to `Workspace.EndBase`, 1597 parts / 947 model pivots
  transformed by direct `part.CFrame` assignment (**not** `PivotTo` — a `PrimaryPart` silently overrides
  `WorldPivot`). Spot checks: `Tent (−398,24,−350) → (398,24,18350)`, `SandbagWall (−310,22,−217) →
  (310,22,18217)`.
- **Stripped 4 game-breakers** from the copy: `SpawnLocation` (would have spawned players 18,000 studs
  downstream), `Plane` (wrong story beat at a destination), `Dock.BoatPlace`, `Dock.PlacePlace`.
- **Named `EndBase`, not `SpawnBase`** — eight server systems bind to `Workspace.SpawnBase` by name
  (Staging, BoatServer, PlaneServer, StartShopServer, FoliageServer, GameSoundscape, ExcursionServer).
  All use explicit `FindFirstChild("SpawnBase")`, so a differently-named copy is invisible to them.
- **Reference chunks 69–70** were generated so the user could sculpt against the real seam, then cleared
  (generated band → 0 voxels; sculpt voxel count unchanged at 426,318).

## Measurements taken

The generated cross-section at the junction is **deterministic** — `centerlineX`/`widthAt` are locked
there and the hill noise uses constant offsets (`HOFF1, HOFF2 = 13.2, 27.7`), not seeded ones. Verified
across two seeds: identical from x −378 to +382; only the outermost voxel column varies, because
`chunkRegion`'s X extent is derived from the seeded centreline over the whole chunk.

```
z=17996 (generated)  water x[-150..+146] w=296   land x[-398..+390]   surface y=12
z=18000 (sculpt)     water x[ -74..  +74] w=148  land x[-298..+678]   surface y=12
```

Water level and channel centre matched for free. The user reviewed the result and accepted the junction
as-is, so the width and land-extent gaps were **not** sculpted out — see the open item below.

## Findings logged

- **0027** — snow-capped hills flank the tropical river (`SNOW_Y = 40`, hills reach y = 64). Affects the
  whole corridor, not just the end.
- **0028** — the START junction has a lateral notch the editor hides: the sculpt's z 0..28 apron, the
  only part wide enough to meet the generator, is overwritten by `chunkRegion(0)` every run.

## Open

- Mouth is 148 wide against the generator's 296, and the sculpt's −X side stops 100 studs short of the
  generated land edge at x −398. Accepted by the user for now.
- The user then built the extraction airfield on the copy (RangerTower ×3, RunWay ×3, Plane, `Escape`
  marker) — wired up in **Job #111**.
