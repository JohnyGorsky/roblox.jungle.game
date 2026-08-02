# Job #070: GAME place — migrate the boat art from the lobby

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Requirements Gathering (intake) — **plan below, awaiting go-ahead**

## Goal

Move every asset the **GAME place** actually needs out of the lobby, starting with the **18 boat
meshes**, and finish the post-import steps so the boat renders as art instead of greybox.

---

# Part 1 — What I found (read before doing anything)

## 1.1 The game place is asset-empty

Scanned live via Studio MCP (`Last River COOP Game`, Edit mode):

| | |
|---|---|
| `ServerStorage` | **only `Inventory`** (a Rojo-synced script folder) — **no `AssetLibrary` at all** |
| MeshParts in the whole place | **0** |
| Sounds | **0** |
| Decals/Textures | 1 |
| `Workspace` | `EditorPiers` (97 desc), `Terrain`, `SpawnLocation`, `Camera` |

**Scripts are all present** — Rojo syncs `sync/` fine. It is *only* the art that is missing, exactly as
`ASSETS.md` §2 warned: *"imported into the LOBBY place only… the GAME place needs the same GLBs."*

## 1.2 The code is already ready for the art — nothing to write

All shared modules are **byte-identical** between the two trees (verified by `diff`):
`BoatParts` · `BoatPaint` · `MonetizationDefs` · `ModuleDefs` · `SkillDefs` · `RetentionDefs` ·
`RankDefs` · `ProfileConfig` · `AdminDefs`.

`BoatParts.LIBRARY_PATH = { "AssetLibrary", "BoatParts" }` under `ServerStorage`, and until the art
exists `skin()` silently does nothing and the boat stays greybox — deliberately. **So this job is an
asset move, not a code change.**

## 1.3 The boat is the ONLY thing that needs an asset library right now

I checked every world-building system. They are all **procedurally greyboxed at runtime**:

| System | State |
|---|---|
| `FoliageServer` | *"greybox jungle trees"*, streamed along the banks |
| `DockServer` | *"greybox plank + fuel drum"* |
| `ObstacleServer` | non-colliding triggers placed by `RiverBootstrap` |
| `EnemyServer` | no model/mesh references — greybox |
| Audio | **zero `Sound` instances created anywhere in `sync/`** |

`ASSETS.md` §3 (river/world), §4 (enemies) and §6 (global audio) are all `▫ stub`, which matches.
**Nothing else has a defined art contract to migrate into.** Trying to move foliage or props now would
be inventing scope.

## 1.4 The 18 meshes to move

From `BoatParts.Defs` (`library` / `upgradeLibrary` fields). 18 distinct names covering 20 part slots —
`Motor` is reused by `motor2`, `GunSeat` by the crew seats.

`Hull`* · `CargoDeck`† · `Motor` · `DriverSeat` · `GunBase` · `GunBarrel` · `GunBarrelHeavy` ·
`GunSeat` · `BowLight` · `HullPlate`* · `FuelTank` · `SearchlightMast` · `SearchLightHead` ·
`CargoRacks` · `RampBow`* · `FuelStation` · `RepairStation` · `MedicStation`

- \* **paintable** (`Hull`, `HullPlate`, `RampBow`) — these need a `PaintablePBR` appearance or the Boat
  Paint Pack liveries render flat. The lobby has exactly **3**, which matches.
- † `CargoDeck` is the only one with `collision = "deck"` — players stand on it, so it needs real
  collision, not the `Box` default.

⚠️ **Names must match exactly.** `BoatParts` clones **by child name**; a typo silently leaves that part
greybox. Note the inconsistent casing in the source of truth: **`SearchLightHead`** (capital L) but
**`SearchlightMast`** (lowercase l). Copy, don't retype.

## 1.5 Two things worth deciding (not blockers)

- **`Workspace.EditorPiers`** — 97 descendants of hand-placed piers, and **no script references it**.
  `DockServer` generates its own greybox docks instead. Is this your in-progress pier work awaiting
  wiring (cf. `todo/0015`, *reel-the-boat-at-every-pier*), or leftovers? *Not part of this job.*
- **The game place has no audio at all.** The lobby's 20 audio ids and 32 UI image ids are universal
  and would port for free (`LOBBY-ASSET-INVENTORY.md` §8) — but the game tree has no `UI/Theme.luau`
  and no soundscape script, so that is a build job, not a migration. *Out of scope here.*

---

# Part 2 — The step-by-step plan

## Method: copy-paste between the two open Studio instances

**Both Studios are open right now** (`Last River COOP lobby` and `Last River COOP Game`), which makes
this the fastest and most faithful route: copying instances preserves the meshes, **their
`SurfaceAppearance` PBR maps, and the `PaintablePBR` appearances the lobby already has** — so most of
the post-import work is already done for us.

The alternative — re-importing the 18 GLBs from `assets/Images/Boat/Objects/` via the 3D Importer —
would mean renaming all 18 by hand and re-running the paint prep. Slower and more error-prone.

> A script cannot do this part. `MeshPart.MeshId` and `SurfaceAppearance.ColorMap` are both gated
> ("lacking capability Plugin"), which is exactly why `BoatParts` uses a clone-from-library convention
> instead of setting `MeshId` at runtime.

### Step 1 — copy the library out of the LOBBY *(you, Studio)*
1. Focus the **`Last River COOP lobby`** Studio window.
2. Explorer → `ServerStorage` → `AssetLibrary` → select the **`BoatParts`** folder.
3. **Ctrl+C**.

> Copy **only `BoatParts`**, not the whole `AssetLibrary`. The lobby's library also holds Foliage,
> Plane, Rocks, Logs, Props, Structures, Characters and Signs — none of which the game place has a use
> for yet, and all of which would bloat it.

### Step 2 — paste into the GAME place *(you, Studio)*
1. Focus the **`Last River COOP Game`** Studio window.
2. In `ServerStorage`, create a **`Folder` named exactly `AssetLibrary`** (it does not exist yet).
3. Select that `AssetLibrary` folder → **Ctrl+Shift+V** (*Paste Into*), so the result is
   `ServerStorage.AssetLibrary.BoatParts`.
4. **Save the place** (Ctrl+S). *`ServerStorage` is place content — nothing here is synced by Rojo.*

### Step 3 — I verify the import *(me, MCP)*
Read back `ServerStorage.AssetLibrary.BoatParts` and check:
- all **18** expected names present, spelled exactly (I will diff against `BoatParts.Defs`)
- every one is a `MeshPart` with a non-empty `MeshId`
- `SurfaceAppearance` count carried over (lobby has **21**)
- `PaintablePBR` present on the **3** paintable parts

### Step 4 — post-import fixes *(me + you)*
1. If any `PaintablePBR` is missing, run in the **game place** command bar and **save**:
   `local BP = require(game.ReplicatedStorage.Boat.BoatParts) print(BP.preparePaintLibrary())`
2. Set **`CargoDeck.CollisionFidelity = PreciseConvexDecomposition`**. `BoatParts.applyLibraryFidelity()`
   exists for this, but its own comment warns the property is *"silently ignored outside the Properties
   panel"* — so **set it by hand in Properties** and re-check the value stuck.
3. **Save the place again.**

### Step 5 — verify in Play *(me, MCP)*
Concrete checks, not eyeballing:
- the spawned boat's parts have **`MeshId`s** (art) rather than plain greybox blocks
- **no** `[BoatParts] "<name>" missing from ServerStorage.AssetLibrary.BoatParts` warnings in the console
- a **livery applies** to hull + plates and does *not* bleed onto deck/engines/seats
- a player can **stand on the `CargoDeck`**
- `RampBow` sits where expected — ⚠️ known quirk (`ASSETS.md` §2): it imported with a **square
  footprint**, so it rides low on the foredeck and passes *under* the gun base

### Step 6 — record it
- `ASSETS.md` §2: drop the *"imported into the LOBBY place only"* warning once it is true of both.
- `LOBBY-ASSET-INVENTORY.md` §8: mark the boat-mesh row transferred.
- Registry `meshes.md` already lists all 18 — no change needed.

## Open questions

1. **`EditorPiers`** — wire it up, or is it work in progress? (Only affects whether it becomes a job.)
2. After the boat lands, what next for the game place — **audio** (20 ids port free, needs a soundscape
   script) or the **HUD restyle** (`Theme.luau` port, 32 icon ids)?

## Checklist

- [x] Game logic + current asset state read (Part 1)
- [ ] Plan agreed
- [ ] Steps 1–2 done (user: copy-paste + save)
- [ ] Steps 3–4 done (verify + post-import fixes)
- [ ] Step 5 done (Play verification)
- [ ] Final summary + changelog
