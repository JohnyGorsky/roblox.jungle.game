# Final Summary — Job #070

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — boat art is live in the GAME place, plus one bug the migration exposed

## What was done

### 1. The asset migration (user, in Studio)

`ServerStorage.AssetLibrary` copied from the lobby place into the game place and **saved**.

The user copied the **whole library** (9 folders, 2,070 descendants, 168 MeshParts) rather than just
`BoatParts` as the plan suggested. **That was the better call and the plan was wrong to caution against
it:** `ServerStorage` never replicates to clients, so the cost is place-file size and server memory
only — no client impact — and several folders are needed later anyway (`ASSETS.md` §3 has river piers
*reusing* `AssetLibrary/Structures/Dock`, and the banks will want real foliage).

### 2. Two planned steps turned out to be unnecessary

Copy-paste preserves more than a re-import would have:

- **`PaintablePBR` came across on all 3 paintable parts** → `preparePaintLibrary()` never needed running.
- **`CargoDeck.CollisionFidelity` was already `PreciseConvexDecomposition`** → no manual Properties fix.

Re-importing the GLBs instead would have required both, plus renaming 18 meshes by hand.

### 3. 🔴 The Medic Station never received its mesh — fixed

`CargoServer` builds Fuel and Repair through a `makeStation(...)` helper whose last argument is a skin
key, so both call `BoatParts.skin`. **Medic is built inline in a separate `do` block** that duplicates
the part-creation code and **omitted the skin call.**

So `medicStation` had `library = "MedicStation"` in `BoatParts.Defs`, the mesh sat in the library, and
nothing ever asked for it — the medic station rendered as a **red greybox cube between two properly
modelled stations**, while `ASSETS.md` §2 claimed all three were *"✅ wired"*.

**Invisible until now.** While the whole boat was greybox there was nothing to compare against; the
art migration is what made it visible. Same shape as the lobby's dock-water bug (Job #069 E2): a doc
claiming wired, code not wiring it.

Fixed with one line + a comment explaining why it was missing.

## Files changed

| File | Change |
|---|---|
| `sync/ServerScriptService/Cargo/CargoServer.server.luau` | added the missing `BoatParts.skin(m, "medicStation")` |
| *(place content)* `ServerStorage.AssetLibrary` in the GAME place | copied from the lobby, saved by the user |

## Verification

**Contract-checked against `BoatParts.Defs` itself**, not a hand-written list:

- [x] All **18** required library names present — no missing, no wrong class, no empty `MeshId`
- [x] Spelling exact, including the inconsistent casing (`SearchLightHead` vs `SearchlightMast`)
- [x] **18/18 have a `SurfaceAppearance`**, and **0** have an incomplete PBR set (Color/Normal/Rough/Metal all populated)
- [x] `PaintablePBR` on all 3 paintable parts, each with an **empty `ColorMap`** and normal/rough/metal retained — exactly what liveries need
- [x] No extras in `BoatParts` that `Defs` never asks for

**Play-verified twice:**

- [x] First run: **13 skinned MeshParts**, all with `SurfaceAppearance`; **no `[BoatParts] missing…` warnings**; full boot (river, zones, intro cinematic, crash-site hub)
- [x] After the medic fix: **14** — `Skin_medicStation` present alongside `Skin_fuelStation` and `Skin_repairStation`

Module parts (twin motors, hull plating, searchlight, cargo racks, ramp) are absent because the test
profile owns none **in this place** — correct behaviour, not a gap.

## Outstanding

- `ASSETS.md` §2 still carries the *"imported into the LOBBY place only"* warning — **now false**, and
  its "Fuel · Repair · Medic ✅ wired" note was wrong until this job. To correct in the next doc pass.
- `RampBow`'s known square-footprint quirk (§2) was not re-examined here; it only shows once the
  `ramps` module is owned.
- Untouched by design: the game place still has **no audio** and no `UI/Theme.luau`. The lobby's 20
  audio ids and 32 UI image ids port for free (`LOBBY-ASSET-INVENTORY.md` §8) but need a soundscape
  script and a HUD restyle — build jobs, not migrations.
