# Job #066: Boat: modular part art + static lobby boat per player

**Project**: `roblox.jungle`
**Created**: 2026-07-31
**Status**: Requirements Gathering (intake)

## Requirements / goal

Two halves, one job:

1. **Art** — replace the boat's greybox blocks with **generated modular parts** (you generate each piece,
   I assemble and wire them). The boat must stay **modular**, because upgrades are *physical, visible
   modules bolted on* (GAME.md) — one single-piece boat mesh would break the core progression fantasy.
2. **Lobby** — when a player joins, spawn a **static display boat** in free harbour water, reflecting
   *their* owned modules. Static in the lobby; the game place keeps the rideable one.

## The important finding: the boat already exists

This is **not** a new boat. There is a working modular boat in the game tree, and the part names below are
what scripts already look up **by name at runtime**. **Renaming any of them breaks gameplay.**

| Script | Builds / expects |
|---|---|
| `Boat/BoatServer.server.luau` | `Boat` model · `Hull` · `DriverSeat` (VehicleSeat) · `Root` attachment |
| `Combat/GunServer.server.luau` | `GunBase` · `GunSeat` · `GunBarrel` |
| `Cargo/CargoServer.server.luau` | `CargoDeck` · `Fuel Station` · `Repair Station` · `Medic Station` |
| `Boat/RoleServer.server.luau` | reads `DriverSeat`, `GunSeat`, `Fuel Station`, `Repair Station`, `Medic Station` by name for the role bonuses |
| `Boat/BoatModules.server.luau` | the upgrade parts (table below) |

So the art job is a **like-for-like swap**: each greybox box becomes a mesh under the same name, anchor and
rough footprint. The existing sizes/offsets give us the size brief for free.

## Part list — what to generate

### A. Always present (the base boat)

| Part | Today | Size brief | Notes |
|---|---|---|---|
| `Hull` | one box | **22 long × 14 wide × 3 tall** (`BoatServer.HULL_SIZE`) | The "boat base". Weathered olive riverboat, open deck, flat interior floor players stand on. |
| `CargoDeck` | box | deck plate | The **platform** — wooden deck inside the hull |
| `DriverSeat` | VehicleSeat | seat | **Must stay a `VehicleSeat`** — driving depends on it. Art = seat + the **steering wheel / console** in front of it |
| `GunBase` + `GunBarrel` | box + box | barrel ~5 long | Pintle mount + barrel. The **barrel must stay its own part** — it rotates to aim |
| `GunSeat` | Seat | seat | Gunner's seat beside the mount |
| `BowLightHead` | 1.2³ neon | small lamp head | The **lamp** — every boat gets a bow light at night (`NightLight` tag) |
| `Motor` | **doesn't exist yet** | outboard engine | **New (decision #1)** — the starting boat's "one weak motor" at the stern, sized to match `Motor2` |
| Crew seats | — | seat | 6 stations, free with the hull (decision #3): driver · gunner · repair · refuel · medic · extra crew |

### B. Upgrade modules — one mesh each (`ModuleDefs`, 6 total)

Bought once with Gold in the lobby, then **physically appear** on the boat.

| Module id | Name | Part(s) today | Offset | Art brief |
|---|---|---|---|---|
| `motor2` | Twin Motors Mount | `Motor2` | (−3.5, 1, 10.5) | **Second** outboard engine at the stern, matching the base `Motor` (decision #1 adds that). Owning this = two visible motors |
| `hullkit` | Reinforced Hull | `HullPlateL` / `HullPlateR` | (±7.3, 0, 0) | Bolted armour plates down both flanks, 20 long |
| `fueltank` | Extended Fuel Tank | `FuelTankModule` | (4.5, 2.5, 8) | Jerry can / drum, ~2×3×3 |
| `searchlight` | Searchlight Rig | `SearchlightMast` + `SearchlightHead` | mast (0,5,−7) · head (0,8,−7.6) | Mast + big lamp head. **Two parts** — the head carries the SpotLight |
| `trailer` | Cargo Trailer | `Trailer` | (0, −0.4, 15.5) | ⚠️ **NOT a towed barge** — see the correction below. A **welded** cargo addition behind the stern, ~8×1.5×7 |
| `gunupgrade` | Mounted Gun Upgrade | `GunBarrelUpgrade` | (0, 3, −3) | Heavier barrel replacing/overlaying the base one |

**Total: 8 base pieces (incl. the new `Motor`) + 7 module pieces (searchlight is 2) ≈ 15 meshes.**

## How upgrades impact parts (confirmed in code, not assumed)

Modules are **additive, one-time and visible**. `BoatModules.apply()` checks `crewOwns(id)` and, if owned,
**adds the part and sets an attribute** — `ThrustMul` 1.25, `MaxHP` 150, `MaxFuel` 150, `CargoMax` +10,
`GunTier` 2, `HasSearchlight`.

**They do not swap the boat for a better boat, and there are no module tiers.** Therefore:

- ✅ **One mesh per module**, designed to bolt onto the base hull at the offset above.
- ❌ **No "level 2 / level 3" variants** — modules are bought once. (Same trap that shrank
  `ASSETS.md §1.9b` from 16 renders to 7.)
- ⚠️ The gun is the only part that *changes* rather than adds: `gunupgrade` sets `GunTier = 2` and adds a
  heavier barrel — see open question 2.
- **Skills** (`SkillDefs`, level 1–10) tune numbers only. **No art, no visible change.** A skill must never
  imply a part.

## Correction — there is NO towed trailer (caught by user, 2026-07-31)

An earlier draft of this intake described the `trailer` module as "a towed barge behind the boat", taken
from `ModuleDefs`' blurb. **Wrong — towing was deliberately removed.**

- **Job #013 final summary:** an earlier towed-trailer version *"was built then replaced"* because a towed
  second body was *"fiddly/jittery per roblox-physics"*. It became a **massless welded** rear deck.
- **`CargoServer` header:** *"Cargo … is stored ON the boat — ONE rigid assembly, **no towed body** … a
  towed second body is the fiddly/jittery path."*

**Two live problems this exposed** (logged as finding **0003**):

1. **The module is invisible.** `Trailer` (8×1.5×7) is welded at Z 15.5, which falls entirely inside the
   rear `CargoDeck` footprint (Z 11…27) and 1.4 studs below it. A 180-Gold upgrade that cannot be seen
   directly contradicts GAME.md's "upgrades are physical, visible modules" pillar.
2. **Its player-facing name lies.** `ModuleDefs` still says *"A towed barge — carry more loot."*

**Art consequence:** do **not** model a towed barge. The cargo upgrade should read as *visible cargo
capacity added to the existing boat* — raised side racks, stacked crates, a raised rear cargo frame —
positioned so it is actually visible above the rear deck.

## Reading the mockup (`assets/Images/boat_ideas.png`)

Genuinely useful for silhouette, palette and station layout — but per the standing rule it is **direction,
not spec**, and three things in it don't exist in this game:

| Mockup shows | Reality in code | Verdict |
|---|---|---|
| **3 boat classes** — Scout / Utility / Heavy Gunboat | One hull + bolt-on modules. GAME.md is explicit: *"start with a small, basic boat … build it up"* — a growth curve, not a class pick | **Don't build 3 boats.** Treat the three as silhouette references for one hull that grows |
| **7 modules**, incl. "Repair Speed" | 6 modules. "Repair Speed" is a **skill** (`repair` / Field Repair), and skills have no art | Generate 6 |
| "Cargo Size" · "Utility Equipment" | `trailer` · `searchlight` | Same things under our names |
| 6 numbered stations (driver / gunner / cargo / repair / refuel / extra seat) | **All real** — `RoleServer` grants bonuses at exactly these stations | ✅ follow closely; the best part of the sheet |

## The lobby boat

- **Static display.** Anchored, no physics, no driving. The rideable boat stays `BoatServer`'s in the game
  place — **nothing about the game-place boat changes in this job.**
- **One per joining player** in **free harbour water** — needs a mooring-slot picker so two players' boats
  never overlap. The dock and east water lobe already exist (`AssetLibrary/Structures/Dock`, `Dock.Pier`).
- **Shows that player's owned modules**, so the lobby boat becomes a **showroom** for the Boat Upgrades
  shop — you can see what you've bought and what you haven't — rather than set dressing.
- Reuses `ModuleDefs` + the player's profile; the module→mesh mapping is shared with the game boat.

## Constraints

- **Names are an API.** `Hull`, `DriverSeat`, `GunSeat`, `GunBase`, `GunBarrel`, `CargoDeck`,
  `Fuel Station`, `Repair Station`, `Medic Station` are all resolved by name at runtime. Keep them.
- **`DriverSeat` must stay a `VehicleSeat`**; `GunSeat` and the stations must stay seats — `RoleServer`
  checks `:IsA("Seat")` / `:IsA("VehicleSeat")`.
- **Set `CollisionFidelity` deliberately on every mesh import** — players stand on the deck and move around
  the hull interior, and imported meshes default to Box collision, which would seal the boat shut
  (memory: `meshy-collision-fidelity`).
- **Mobile perf** — 6 players, plus modules, plus a towed barge. Watch part and tri counts (P8).
- Two trees: the lobby boat is lobby-only; any shared mapping module must be byte-identical in both.

## Decisions (user, 2026-07-31) — all intake questions resolved

| # | Decision |
|---|---|
| 1 | **Add a base `Motor`.** Every boat has one; buying `motor2` gives you **two visible motors**. |
| 2 | **The gun upgrade is a MESH SWAP, not an addition** — "we will have our own model, so we just replace models". `GunBarrelUpgrade` replaces the base `GunBarrel`'s look; one barrel is visible at any time. |
| 3 | **All 6 stations ship free with the hull.** No seat module, no paid crew capacity (paid = convenience/cosmetics only, GAME.md). |
| 4 | **One hull mesh.** Hull scaling stays an open *design* question, not something this job closes off. |
| 5 | **Concept sheet → image-to-3D.** You render one ChatGPT sheet with every part in our palette, then Meshy image-to-3D per piece, so 14 meshes read as one boat. |
| 6 | **Mooring slots are generated in code** along the dock / east water lobe (not hand-placed). ⚠️ This is a deliberate exception to the lobby's editor-placed rule — noted below. |

### Consequence of #1 and #2: the part mapping must be DATA, not code

The user also flagged: *"later we can add a different motor (model) so it looks more cool."* Combined with
the gun being a swap, that means **which mesh represents a part must be swappable without touching logic.**

So the job introduces a shared **`BoatParts`** mapping module — part/module id → mesh asset id + offset +
scale + collision fidelity — and the boat builders read from it. Dropping in a cooler motor later becomes a
one-line id change in one file, in both trees, with no gameplay code touched. Without this, every future
model swap means editing `BoatModules`/`BoatServer` and re-testing physics.

This also gives the **lobby** boat and the **game** boat a single source of truth for what a boat looks
like, which is the only sane way to keep a showroom honest.

### Consequence of #6: code-generated mooring slots

The lobby is otherwise editor-placed (memory: `lobby-editor-placed-not-scripted`). Generating slots is the
user's explicit call here, so:

- Slots are derived from the **existing dock and water lobe**, not invented positions — anchor off
  `AssetLibrary/Structures/Dock` / `Dock.Pier` and the water surface.
- The generator must be **verified by read-back + screenshot** (memory: `verify-studio-terrain-edits`) and
  must never place a boat intersecting the dock, another boat, or dry land.
- If the spacing reads badly in-world, the fallback is hand-placed `BoatSlot_*` anchors — cheap to switch
  to, since the finder would just prefer them when present.

## Checklist

- [x] Requirements reviewed (this intake) — all 6 decisions locked 2026-07-31
- [x] Implementation plan created — **awaiting go-ahead**
- [ ] Implementation completed
- [ ] Final summary + changelog written
