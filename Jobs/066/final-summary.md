# Final Summary — Job #066

**Project**: `roblox.jungle`
**Completed**: 2026-08-01
**Status**: ✅ Completed (lobby scope) — **two items carried forward, see below**

## What was implemented

The boat went from a greybox box to a modular, art-dressed river craft, and the lobby gained a per-player
**showroom boat** moored in the harbour.

### 1. `BoatParts` — art as data, never as code

The boat is assembled from parts that gameplay resolves **by name at runtime** (`Hull`, `DriverSeat`,
`GunSeat`, `GunBase`, `GunBarrel`, `CargoDeck`, the stations). Their *appearance* now lives in
`ReplicatedStorage.Boat.BoatParts` — a byte-identical module in both trees mapping part → mesh, size,
offset/rotation and collision mode.

**The golden rule it enforces: art never touches physics.** `Hull` stays a plain box — it is the
`PrimaryPart`, carries the tuned density that makes the boat float, and hosts the `Root` attachment every
thrust and turn force acts through. Each mesh is welded on as a `CanCollide = false`, `Massless = true`
**skin**. Mass, centre of mass, buoyancy and collision are untouched by any art change, and swapping a
model is one id in one file.

Phase 1 deliberately shipped **with no art at all**, so the refactor of physics-owning code could be
proven with one variable changed rather than fifteen. That gate passed before a single mesh arrived.

### 2. The art — 15 meshes

ChatGPT concept renders → Meshy image-to-3D → imported to `ServerStorage/AssetLibrary/BoatParts/`.
15 meshes cover 17 part slots (`Motor2` reuses `Motor`; crew seats reuse `GunSeat`). Ids in registry
[`meshes.md`](../../../roblox.workspace/Assets/registry/meshes.md); the boat's part table is `ASSETS.md` §2.

Boat changes that came out of dressing it:

- **Hull 22 → 32 studs.** It read as smaller than its own rear deck, and 32 × 14 is the mesh's *exact*
  natural ratio — so the skin no longer has to be stretched 46% wider than modelled, which is what made it
  look squat and low in the water. ⚠️ **This changes physics** (see carried-forward).
- **Rear deck 16 → 8 long** — it was bigger than the boat it sat behind.
- **A base `Motor`** now exists; `motor2` is genuinely its twin rather than an engine appearing from nowhere.
- **Gun upgrade is a model SWAP**, not a second barrel bolted on.
- **4 crew seats** — real `Seat` objects, so passengers on a boat that pitches and banks are welded rather
  than sliding overboard. Driver + gunner + 4 = the 4–6 crew `GAME.md` targets.
- **Module offsets are derived from the hull**, not hardcoded, so the next length change won't strand them.

### 3. `LobbyBoat` — the harbour showroom

On join, each player gets their **own static boat** moored in free harbour water, showing exactly the
modules they own — turning the Boat Upgrades shop into a showroom. Mooring slots are **probed from terrain
water** around the real dock (whole-footprint clearance, nearest-pier-first), not hardcoded. It rebuilds
live when a module is bought, via a `ModulesRev` attribute that keeps the shop and the showroom decoupled.

### Files changed

**New** — `ReplicatedStorage/Boat/BoatParts.luau` (both trees) · `ServerScriptService/LobbyBoat.server.luau`
**Changed** — `BoatServer` (hull size, base motor, crew seats) · `BoatModules` (derived offsets, tiled
plates, skin hooks) · `GunServer` (mount height, barrel on the mount, seat placement) · `CargoServer`
(deck depth, skin hooks) · `ModulesServer` (`ModulesRev`) · `Theme` · `ASSETS.md` · `GAME.md` · registry
`meshes.md`

## Verification

- [x] Analyzer clean on every touched file, **both trees**, after every change.
- [x] **Phase-1 handling gate passed by the user** — boat felt unchanged with the harness in, before art.
- [x] Every mesh verified in a **fresh** Play session: skin attached, host hidden, `SurfaceAppearance`
      carried, position measured against the hull rather than eyeballed.
- [x] Mooring verified by read-back: hull over `Water`, correct draft, clear of the pier.
- [x] Gun upgrade **swap** path exercised (base 4.6 × 2.3 × 1.6 vs heavy 5.5 × 2.4 × 2.3 — distinct).
- [x] Lobby boat: **zero greybox parts remaining.**

## What the art pass taught us (worth keeping)

1. **Old offsets were tuned against a 3-stud greybox slab.** The real hull has a raised foredeck, so the
   bow light, gun mount and gunner seat all ended up buried in it. Now named constants.
2. **A mesh's longest axis is not automatically its "forward".** The driver's seat is elongated
   seat→console and needs a yaw; the gunner's is near-cubic where the long axis is the seat's *width*, so
   the same yaw turned the gunner sideways. Check what the axis means; don't copy the last part's rotation.
3. **A repeating detail tiles; it never stretches.** One hull plate scaled to full length smeared its bolts
   *and* overhung the hull's taper. Four short plates along the parallel midbody fixed both.
4. **Size the skin to the MESH, not the host.** The barrel stretched to its 8-stud host read as a rod
   skewering the bow; the host is an invisible aim pivot.
5. **Mesh geometry can sit high inside its bounding box** — the deck stations needed a hand correction on
   top of the derived maths.
6. **Restart Play before judging an edit.** A stale session showed the stations floating while the data
   said sunk, and sent me a full stud the wrong way.

## Engine constraints discovered (cost real time — don't rediscover)

- **`CollisionFidelity` cannot be written by a script.** Not at runtime (throws, taking the whole build
  down) and silently ignored from the command bar. Properties-panel or importer only. It doesn't matter
  here: the greybox host carries collision, and a box is the right shape for a deck anyway.
- **`MeshPart.MeshId` likewise isn't settable at runtime** — which is exactly why `BoatParts` clones from a
  library by **child name**. Renaming a library part breaks the boat.
- **Terrain water: voxel centre ≠ surface.** Voxels are 4 studs and only partly filled at the top; using
  the centre put every boat 2 studs too low and water washed through the deck. Use base + occupancy.
- **Skins can't be raycast** (`CanQuery = false`, `Box` fidelity) so the true mesh surface is unmeasurable
  at runtime — some seating offsets are necessarily tuned by eye and are commented as such.

## Carried forward (deliberate, not dropped)

1. **Import the 15 GLBs into the GAME place.** `ServerStorage` is place content and Rojo does not sync
   meshes, so the game boat is still fully greybox. Same names; `BoatParts` is already identical in both
   trees, so it will work the moment they land. Files: `assets/Images/Boat/Objects/`.
2. **Re-test boat handling in the game place.** The hull grew 22 → 32 studs — more volume and length alters
   buoyancy, inertia and turning, so `THRUST` / `DRAG` / `TURN` may want retuning. **This is the only change
   in the job that affects how the boat plays rather than how it looks, and it is still unverified.**
3. **Save the lobby place** — imported meshes are place content.
4. **Upgrade-item shop art** (`ASSETS.md` §1.9b, 7 renders) — unrelated to the boat itself; the Boat
   Upgrades panel shows icon + text until it exists.
