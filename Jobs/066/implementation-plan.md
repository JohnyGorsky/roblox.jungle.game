# Implementation Plan — Job #066

**Project**: `roblox.jungle`
**Created**: 2026-07-31
**Status**: Planning (awaiting go-ahead)

## Analysis

### The one thing that must not break: boat handling

`BoatServer` makes `Hull` the **`PrimaryPart`**, gives it tuned `CustomPhysicalProperties(DENSITY, …)` —
which is what makes the boat *float* — and parents the **`Root` attachment** to it, which every thrust,
turn and orientation force acts through. Boat feel (momentum, acceleration, drift) was deliberately tuned
in the P1 spike and is a stated core pillar.

**Swapping `Hull` for a mesh would change mass, centre of mass, buoyancy and collision shape at once, and
silently retune the whole boat.** That is the biggest risk in this job and it is entirely avoidable.

**Approach: visual skin over the physics body.**

- `Hull` stays a **box, exactly as now** — same size, density, PrimaryPart, `Root` attachment. It becomes
  **`Transparency = 1`, collision unchanged.**
- The hull *mesh* is a **separate welded child** (`HullSkin`), `CanCollide = false`, `Massless = true`.
- Same for every module: the greybox box keeps whatever collision/behaviour it has; the mesh rides on it.
- **Exception — surfaces players stand on.** The deck must be walkable, so `CargoDeck` keeps real
  collision. If its mesh needs precise collision, that is the one place to spend
  `PreciseConvexDecomposition`.

This means **physics, buoyancy and handling are untouched by the art pass** — an art change can never
retune the boat. It costs one extra part per visual piece, which `Massless` keeps free physically.

### Part identity is an API

`Hull`, `DriverSeat`, `GunSeat`, `GunBase`, `GunBarrel`, `CargoDeck`, `Fuel Station`, `Repair Station`,
`Medic Station` are resolved **by name at runtime** by `RoleServer`, `GunServer`, `CargoServer` and
`BoatModules`, and `RoleServer` type-checks seats with `:IsA("Seat")` / `:IsA("VehicleSeat")`. Names and
classes are frozen; only appearance changes.

### `BoatParts` — the mapping module (from intake decisions #1/#2)

A shared data module so "which mesh is this part" is **data, not code**:

```
BoatParts.Defs = {
  hull      = { mesh = "rbxassetid://…", offset = CFrame.new(0,0,0),      scale = 1, collision = "skin"  },
  motor     = { mesh = "…",              offset = CFrame.new(3.5,1,10.5), scale = 1, collision = "skin"  },
  motor2    = { mesh = "…",              offset = CFrame.new(-3.5,1,10.5),scale = 1, collision = "skin"  },
  gunBarrel = { mesh = "…", upgradeMesh = "…" },   -- decision #2: SWAP, not add
  …
}
```

- `collision = "skin"` → `CanCollide false`, `Massless true` (the default for everything decorative).
- `collision = "deck"` → real collision + `PreciseConvexDecomposition` (the walkable deck only).
- `upgradeMesh` encodes the gun swap: **one barrel visible at a time.**
- Adding a cooler motor later = **change one id in one file**, no gameplay code touched, no physics retest.
- Lives in `ReplicatedStorage/Boat/BoatParts.luau`, **byte-identical in both trees** (like `RankDefs`), so
  the lobby showroom boat and the game boat cannot drift apart.

### Why phase 1 ships with no art at all

The mapping and the skin mechanism are refactors of working, physics-tuned code. Landing them **while the
meshes are still greybox** means any handling regression is caught with one variable changed, not fifteen.
Art then drops into a proven harness.

## Implementation steps

**Phase 1 · Harness, no art yet** — <span style="color:#2e9c3f">✅ CODE DONE 2026-07-31</span>, awaiting the handling gate

1. [x] **`BoatParts.luau`** — 17 part defs + the 6 module→part mappings, every `library` field empty.
       Mirrored byte-identically into `lobby/sync/` (verified with `diff`).
2. [x] Skins wired into **4** scripts (one more than planned — `CargoServer` owns the deck and stations):
       - `BoatServer` → `hull`, `driverSeat`, `motor`
       - `BoatModules` → all 8 module parts, via a new optional `skinId` on `addPart`
       - `GunServer` → `gunBase`, `gunSeat`, `gunBarrel`
       - `CargoServer` → `cargoDeck` (the one part keeping real collision) + fuel/repair stations
3. [x] Base **`Motor`** added at the stern `(3.5, 1, 10.5)` — mirroring `Motor2` at `(−3.5, 1, 10.5)`, so
       buying the upgrade gives two matching motors.
4. [x] **Gun upgrade implemented as a swap** (decision #2): re-skins the existing `GunBarrel` with
       `upgradeLibrary`. Falls back to today's greybox marker part when no art exists, so behaviour is
       unchanged for now.
5. [ ] **Handling gate — needs you.** Play the **game place** and confirm the boat feels identical.

**Phase 1 verification so far**

- Analyzer clean on all 5 edited files, **both trees**. One real bug caught: `CollisionFidelity` is a
  `MeshPart` property, not `BasePart` — now set only on MeshParts, and skins get `Box` (cheapest) while the
  deck gets `PreciseConvexDecomposition`.
- **Runtime smoke test in Studio:** module loads (17 defs, 6 mappings); with no art imported `hasArt` is
  false for every part; `skin()` returns nil and **leaves the host's `Transparency` at 0**, i.e. the
  greybox is genuinely preserved; an unknown id warns and returns nil rather than erroring.
- ⏳ Not yet verified: boat *feel*. That needs the game place open and a human at the wheel.

**Phase 2 · Concept sheet (yours) → meshes**

5. I produce the **generation brief** below; you render one ChatGPT sheet with all 15 parts in our palette.
6. You run Meshy image-to-3D per part and hand me the asset ids.
7. I fill `BoatParts`, set collision per part, and verify each mesh loads and sits at the right offset.

**Phase 3 · Lobby showroom boat**

8. `LobbyBoat.server.luau` — on `PlayerAdded`, build a **static** boat (anchored, no physics, no seats
   active) from `BoatParts`, showing **that player's owned modules** from their profile.
9. **Mooring slots generated in code** (intake #6): derive N slots from the existing dock / east water lobe,
   claim a free one per player, release on leave. Never intersect the dock, another boat, or dry land.
10. Rebuild that player's boat when they buy a module, so the showroom updates live from the shop.

**Phase 4 · Polish + perf**

11. Idle motion — gentle bob/sway on the moored boats (tween, not physics).
12. Perf pass: part and tri counts with 6 boats moored (P8 mobile budget).

## The generation brief (for your concept sheet)

One sheet, top-down/three-quarter, all parts laid out separately on a neutral ground, **in the STYLEGUIDE §4
military palette** — Primary Military Olive `#59613B`, Weathered Metal `#4E5246`, Dark Metal `#353A35`,
weathered wood `#72502D`, brass/gold fittings `#D69B22`. Faded, never glossy. Silhouette reference: the
three boats in `assets/Images/boat_ideas.png` — **one hull that grows, not three classes.**

| # | Part | Size (studs) | Brief |
|---|---|---|---|
| 1 | `HullSkin` | **22 L × 14 W × 3 H** | Open-top riverboat, weathered olive, flat interior floor, rope/tyre fenders. The one hero piece. *(Exact `HULL_SIZE` from `BoatServer` — the earlier "20" was inferred from the armour plates and was wrong.)* |
| 2 | `CargoDeck` | deck plate inside hull | Worn wooden planking |
| 3 | `Motor` | ~2×2×3 | Single small outboard, stern. Humble — this is the "weak" starting engine |
| 4 | `Motor2` | ~2×2×3 | Its twin, mirrored to port |
| 5 | `DriverSeat` + wheel | seat ~4×1×5 | Seat, console and **steering wheel** |
| 6 | `GunBase` | pintle mount | Ring mount on the deck |
| 7 | `GunBarrel` | ~5 long | Base machine gun barrel |
| 8 | `GunBarrelUpgrade` | ~5 long, heavier | **Replaces** #7 when owned — visibly bigger calibre |
| 9 | `GunSeat` | seat | Gunner's low seat beside the mount |
| 10 | `BowLightHead` | ~1.2³ | Small bow lamp |
| 11 | `SearchlightMast` | 0.8×6×0.8 | Thin mast |
| 12 | `SearchlightHead` | ~2³ | Big lamp head (carries the SpotLight) |
| 13 | `FuelTankModule` | 2×3×3 | Jerry can / fuel drum, strapped down |
| 14 | `HullPlate` (L/R mirrored) | 0.6×2×20 | Bolted armour strip down a flank |
| 15 | `Trailer` | 8×1.5×7 | Small towed cargo barge |

Plus the 4 **station props** (repair / refuel / medic / extra seat) if you want them distinct from a plain
seat — they currently exist as coloured boxes and would read better as a toolbox, fuel post, medkit crate
and bench.

## What I need from you

- [ ] **Go-ahead on this plan.**
- [ ] **After phase 1:** a Play test in the **game place** to confirm handling feels unchanged — you know
      how the boat should feel better than a screenshot can tell me.
- [ ] **The concept sheet**, then the Meshy asset ids per part (phase 2 is blocked on these).
- [ ] Rojo sync + place save as usual.

## Verification

- [ ] `tools/luau-analyze.sh` clean on every edited file, **both trees** (`--lobby` and game).
- [ ] **Phase 1 handling gate** — thrust, turning, buoyancy, gun aim and all four station bonuses
      identical to today, with the boat still greybox.
- [ ] Every mesh: read back after import — right part, right offset, **`CanCollide`/`Massless` per the
      `collision` field**, and the deck still walkable (memory: imported meshes default to Box collision).
- [ ] Lobby: N boats moored with **no intersection** with the dock, each other, or land — verified by
      read-back **and** screenshot, not by eye alone.
- [ ] Showroom correctness: buy a module → that player's moored boat gains the part; a player with no
      modules shows the bare starting boat.
- [ ] Perf: part/tri count with 6 boats moored, against the P8 mobile budget.

## Risks

| Risk | Mitigation |
|---|---|
| **Art pass silently retunes boat handling** | The skin approach: `Hull` box, density, PrimaryPart and `Root` are never touched. Phase-1 gate proves it before art exists. |
| Imported mesh seals the boat (Box collision) | `collision` is explicit per part in `BoatParts`; skins are `CanCollide false`; only the deck gets precise collision. Verified by read-back. |
| 15 meshes drift in style | One concept sheet first (intake #5), not 15 independent text-to-3D generations. |
| 6 moored boats blow the mobile budget | Skins are `Massless`, static boats are anchored with no physics; perf counted in phase 4, and the moored boat can drop the trailer/plates at distance if needed. |
| Code-generated slots look wrong or overlap | Slots derived from the real dock/water lobe, read-back + screenshot verified; hand-placed `BoatSlot_*` anchors are the drop-in fallback (finder prefers them when present). |
| Two trees drift | `BoatParts` mirrored byte-identically, same convention as `RankDefs`/`ProfileConfig`. |

## Out of scope

Rideable-boat behaviour changes · river/terrain · the boat's stats or balance · new modules beyond the 6 in
`ModuleDefs` · hull scaling (left an open design question by intake #4) · the game-place UI.
