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
5. [x] **Handling gate — PASSED (user, 2026-07-31).** Played the **game place**; the boat feels unchanged
       with the harness in and the base `Motor` added. The refactor touched physics-owning code, so this
       was the gate that mattered — art can now drop in without physics risk.
       *(The lobby place needs no test here: it has no boat until phase 3, and the mirrored `BoatParts`
       was already confirmed loading there by the smoke test.)*

**Phase 1 verification so far**

- Analyzer clean on all 5 edited files, **both trees**. One real bug caught: `CollisionFidelity` is a
  `MeshPart` property, not `BasePart` — now set only on MeshParts, and skins get `Box` (cheapest) while the
  deck gets `PreciseConvexDecomposition`.
- **Runtime smoke test in Studio:** module loads (17 defs, 6 mappings); with no art imported `hasArt` is
  false for every part; `skin()` returns nil and **leaves the host's `Transparency` at 0**, i.e. the
  greybox is genuinely preserved; an unknown id warns and returns nil rather than erroring.
- ⏳ Not yet verified: boat *feel*. That needs the game place open and a human at the wheel.

**Phase 2 notes — first real mesh in (2026-07-31)**

**`CollisionFidelity` cannot be set by a runtime script.** My plan said I'd set it in code per part; that was
wrong. Roblox gates it behind plugin capability, and the write **throws** —
*"The current thread cannot write 'CollisionFidelity' (lacking capability Plugin)"* — which took down the
whole `buildBoat` call, so no boat appeared at all. It is an **authoring-time** property.
→ `skin()` no longer touches it. `BoatParts.applyLibraryFidelity()` added, to be run **from Studio in Edit
mode** after importing new art (then save the place). Imported meshes default to `Box`, which is already
what a non-colliding skin wants, so in practice only `CargoDeck` needs it changed.
→ **Corrected instruction to the user:** they *should* leave fidelity alone, but because it's set on the
library asset in Studio — not because code does it at runtime.

**Meshes import at an arbitrary scale AND arbitrary orientation.** The hull arrived
**35.06 × 6.60 × 15.33 studs with its length on X**, where the boat's length runs along Z (bow = −Z). Two
new `PartDef` fields handle this without re-exporting anything: **`size`** (exact dimensions, in the mesh's
own local axes) and rotation carried in **`offset`** (a 90° yaw here).

**Proportion mismatch is real and had to be a choice.** The mesh's natural ratio is 2.29 : 1
(length : width); the physics box is 1.57 : 1. A uniform scale to 22 long would leave a 9.6-wide visible
hull inside a 14-wide collision box — you'd stand on water beside it. `size` therefore stretches it to the
box footprint (22 × 4.14 × 14), keeping visual and collision honest at the cost of a beamier boat.

**Verified in Play:** footprint matches the box exactly (22 × 14 world extents on both), the greybox box is
hidden (`Transparency = 1`), the skin is `CanCollide = false` + `Massless = true`, `SurfaceAppearance`
(PBR) carried across on the clone, and the skin stands 1.1 studs taller than the box — gunwales rising
above the physics body, exactly the intent of the skin approach.

**The waterline bug — every boat sat 2 studs too low.** Reported as *"water is going through"*: the
interior deck was under the surface. Cause was in `LobbyBoat.waterTopAt`, not the art — terrain voxels are
4 studs and only PARTLY filled at the surface, and the probe returned the topmost water voxel's **centre**
as the water height. Measured: it reported **−6.00** where the true surface is **−4.00**.
→ Now reads the voxel's base plus its **occupancy**, giving the real surface. After the fix: keel 0.60
below water (as designed), gunwale 5.42 above, rear deck 2.60 above and dry.
→ Worth remembering for any future terrain-water probing: **voxel centre ≠ water surface.**

**Phase 2 · Concept sheet (yours) → meshes**

5. I produce the **generation brief** below; you render one ChatGPT sheet with all 15 parts in our palette.
6. You run Meshy image-to-3D per part and hand me the asset ids.
7. I fill `BoatParts`, set collision per part, and verify each mesh loads and sits at the right offset.

**Phase 3 · Lobby showroom boat** — <span style="color:#2e9c3f">✅ DONE 2026-07-31</span> (greybox; art drops in later)

8. [x] **`lobby/sync/ServerScriptService/LobbyBoat.server.luau`** — on join, builds a **static** boat
       (every part `Anchored`, `CanCollide = false`, no constraints, no usable seats) from `BoatParts`,
       showing that player's owned modules. Layout offsets copied from the game boat so the showroom
       cannot lie. Owner nameplate above each boat.
9. [x] **Mooring slots probed from terrain, not hardcoded.** Reads the water voxels around the existing
       `Pier`, requires the **whole boat footprint** (30×20 with margin) to be over water at a consistent
       surface height, then sorts candidates nearest-pier-first so the harbour fills tidily.
       **Hand-placed `BoatSlot_*` parts override the probe** — the documented fallback, already wired.
10. [x] Rebuild on purchase — `ModulesServer` now bumps a **`ModulesRev`** player attribute (mirroring how
        `Profiles` publishes Gold/RiverScore), and `LobbyBoat` listens. The shop and the showroom stay
        decoupled: neither knows about the other.

**Phase 3 verification (Play, lobby place)**

- `[LobbyBoat] probed 8 mooring slot(s) from the dock at (125, −6)` — 8 valid slots found from real terrain.
- Read-back: hull at **(151, −6.0, 20)**, **material under hull = `Water`**, `Anchored = true`, 10 parts,
  **37 studs clear of the pier**. Not eyeballed — queried.
- Screenshot confirms the boat moored in open water beside the dock with its nameplate.
- Analyzer clean; one dead import (`ModuleDefs`) caught and removed.
- Camera restored to `Custom` after the screenshot (memory: `screen-capture-locks-camera`).

**Fixed after review — the boat was sitting underwater.** The first build put the hull *centre* at the
water line, because that is what the game's buoyancy targets. On a 3-stud-tall hull that leaves it flush,
which is fine for a physics box nobody looks at and wrong for a boat on display.

`LobbyBoat` now has a **`DRAFT`** constant (0.6): the hull bottom sits just under the surface instead.
Measured after the change — hull bottom **0.6 below** water, hull top **2.4 above**, deck 2.4, gun mount
5.4. It reads as floating. **`DRAFT` is the knob to retune once the hull mesh lands**, since a mesh with
real gunwales will want a different value than a plain box.

**Also fixed after review — players fell through the boat.** I had set `CanCollide = false` on every part
to stop players shoving the showroom boat around. That reasoning was wrong: the parts are **`Anchored`**,
so they can't be pushed regardless — the collision was free to keep, and turning it off just made the deck
non-solid. Now all parts collide. Verified: no part has collision off, a downward raycast **hits
`CargoDeck` at exactly its top surface (Y = −3.60)**, and the deck sits 2.4 studs above the water line so
you stand rather than swim.

**Mooring distance — keep it offshore (user, 2026-07-31).** The nearest probed slot is ~37 studs off the
pier, so boarding means swimming out. Offered to berth the boats against the pier for easier access;
**user chose to keep them offshore** — the harbour reads better with boats moored out on the water. Do not
"fix" this later. The `BoatSlot_*` override remains available if that ever changes.

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
