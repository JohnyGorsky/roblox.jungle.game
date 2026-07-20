# Implementation Plan — Job #064: Lobby (Jungle Airfield)

**Project**: `roblox.jungle`
**Updated**: 2026-07-20
**Status**: Base terrain built & verified — next is asset placement → final asset list

Reference: `assets/Images/MapIdea.png`. Applies the `jungle-style` guide (landmark→path→
secondary-area, readable center, mobile-first) and the **no-visible-map-edges** rule.

> **Where the work lives (important):** terrain is **not** synced by Rojo (`lobby/` syncs only
> scripts under `sync/` → services). So the terrain exists in the **Studio place file** only. The
> **reproducible artifact in git** is the generator script:
> [`lobby/build/generate_base_terrain.luau`](../../lobby/build/generate_base_terrain.luau). Re-run it
> in the Command Bar (or via MCP) to rebuild the base from scratch.

## Decisions (via wizard, 2026-07-20)

- **Scale:** Medium — flat sand clearing ~270×236, whole island ~920×660 incl. hills/mountains.
- **Water:** East shore + **SE river mouth** (the boat departs downriver).
- **Base scope:** Claude generates the **procedural base** (terrain + water + zone markers); the
  **human hand-sculpts hero detail** afterwards (GROUND-RULES §2).
- **No visible edges (standing rule):** the clearing is a **valley** — jungle hills rise on all land
  sides, distant snow mountains close every horizon, water runs to a far shore, warm haze fades the
  distance. You can't see the map end or fall off.

## Coordinate system

Plane/spawn at ~origin. **+X = East/water, −X = West/shops, −Z = North/runway, +Z = South/entry.**
Clearing surface at **y = 0**; terrain water surface at **y ≈ −6**.

## Zone layout (marker coordinates, studs)

| Zone | (X, Z) | Notes |
|---|---|---|
| Spawn (star) | (0, −35) | `LobbySpawn` SpawnLocation here |
| Plane + Pilot | (0, 0) | Central landmark |
| Party pad — Blue | (−30, −22) | NW of plane |
| Party pad — Red | (30, −22) | NE of plane |
| Party pad — Green | (−30, 30) | SW of plane |
| Party pad — Yellow | (30, 30) | SE of plane |
| Gold Skill Shop | (−105, −20) | West, gold |
| Small Skill Shop | (−105, 45) | West, blue |
| Boat Dock + Boat | (150, 5) | Over the east water lobe |
| Welcome Sign | (0, 120) | South entry |
| Runway 27 | (0, −155) | Flat corridor cut north through the hills |
| Watchtower NW / NE | (−95, −120) / (90, −120) | North corners |

## Terrain spec (what the generator builds)

- **Clearing:** flat **Sand**, readable center (plane/pads/shops all sit at y≈0).
- **Runway:** flat Sand corridor cut through the north hills (X ∈ [−20,20], Z ∈ [−220,−95]).
- **Land bowl:** height rises with distance beyond the clearing rect (smoothstep to ~58, then climbs
  to a 132-cap) → **Grass** hills (<46), **Rock** (<88), **Snow** peaks. Noise adds ruggedness.
- **East water lobe:** a bay that **bends SE and widens** into the river mouth; sloped sand basin,
  water surface ~y−6 (`Terrain.WaterColor` = river turquoise `36,119,134`).
- **Far shore:** land/mountains east of the lobe close the water horizon (Snow @ ~134).
- **Lighting:** warm afternoon (`ClockTime 15.5`), warm ambient, `Atmosphere` haze to fade distance.
  ⚠ `Lighting.Technology = Future` must be set in Studio (MCP context can't set it) for best AO/water.

## Verification (done)

- **Read-back** (`ReadVoxels`): clearing Sand@0 · far W/N/S Rock@70–78 · east lobe water@−6 over sand
  basin · far-east Snow@134. ✓
- **Screenshots:** eye-level east & west from the middle show hills + snow mountains on every horizon
  (no edge); bird's-eye shows the enclosed valley + turquoise river-mouth bay. ✓

## Division of labour — next

**Human (Studio Terrain Editor):** soften/curve the river banks & beaches, vary the hills, carve
paths, set `Lighting.Technology = Future`, and **save the place**.

**Claude — next steps:**
1. **Asset placement pass** — replace markers with greybox/real props at the coordinates above.
2. **Final lobby asset list** — models/props/signs/pads/boat/plane/foliage → feeds the **assets job**
   (what we need, how many, sourcing, IDs). This is where icons/sounds/models get catalogued.

## What I need from you

- [ ] Walk the base in the lobby place; confirm scale/zone spots feel right (party pads spread? shop
      spots? dock position?).
- [ ] Commit the new repo files (I never commit): `lobby/build/generate_base_terrain.luau`, this job.
- [ ] Go-ahead to start the **asset placement + list** step (or open it as the assets job).
