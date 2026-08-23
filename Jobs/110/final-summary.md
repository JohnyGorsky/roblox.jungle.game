# Job #110 — Final summary

**Project**: `roblox.jungle` · **Status**: COMPLETE

Copied the hand-sculpted START landing basin to the river's end at z = 18000 under a **180° rotation
about the vertical axis through the junction** — `(x,y,z) → (−x, y, 18000−z)` — a rigid transform, so
nothing mirrors: no reversed signage, no inside-out meshes, and the mouth opens *upstream* at the
arriving boat.

- 1,337,251 terrain voxels copied in 8 slabs, verified at 7 landmark points.
- `Workspace.EndBase`: 1597 parts / 947 model pivots, transformed by direct `CFrame` assignment.
- Stripped `SpawnLocation`, `Plane`, `Dock.BoatPlace`, `Dock.PlacePlace` — the first would have spawned
  players 18,000 studs downstream.
- Named `EndBase` so the eight systems that bind to `Workspace.SpawnBase` by name are unaffected.
- Proved the junction cross-section is seed-independent, and handed the user a measured bank profile.
- Reference chunks 69–70 generated for sculpting, then cleared (sculpt voxel count unchanged).

The user accepted the junction as-is, re-sculpted, and built the extraction airfield on it. Wiring it
into the run is **Job #111**.

Findings logged: **0027** (snow-capped hills on a tropical river) and **0028** (the start junction's
hidden lateral notch).
