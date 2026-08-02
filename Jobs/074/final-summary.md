# Final Summary — Job #074

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ **Closed** — 0042, 0043, 0045 shipped and verified in Play; 0044 re-verified

## What was asked

> *"Create one task for game from 0042 - 0045 todos. Read game logic, read what we did in previous job
> and create task where we address these issues."*

The four todos are the leftovers of the **Job #073 playtest**. One of them (0044) turned out to be
already closed, so this job is the other three.

## What each one turned out to be

### TODO 0042 — MEDIC label · the todo's own suggestion was wrong

The todo asked whether removing the label would let `IntroHudGate`'s billboard handling be simplified.
**It doesn't.** That sweep is generic — it disables *every* enabled `BillboardGui` in `Workspace` and
restores only the ones it touched. It never named MEDIC; the header comment cited it as an example.

So: 14 lines deleted from `CargoServer`, the stale comment corrected, **no logic changed**. The gate is
now demonstrably generic — this job also moved the Robux kiosk to an editor-placed hut, and neither
change needed a line in it.

Worth recording *why* the tag existed: Fuel and Repair have never had one, because their
`ProximityPrompt` already names them. Medic is presence-based and has **no prompt**, so the tag was how
it announced itself. Job #070 gave it the real `medicStation` mesh, so it reads without one — and all
three stations now match.

### TODO 0043 — the game place had no design system at all

The todo said *"use the lobby's `RobuxShop.local.luau`"*. That file could not be copied, because it is
built entirely on modules the game tree **did not have**: `Theme` (224), `Components` (1011), `UISound`
(112), `UIBus` (33). All 16 game HUD scripts are hand-rolled greybox on raw `Color3`/`Enum.Font`.

`Theme.luau`'s own header had been waiting for this:

> *"Lobby tree only for now; the byte-identical `sync/` copy is added when the game place is restyled."*

**The two shops had also diverged in behaviour, not just looks** — the game's was the Job #046 original
and never received #065/#067/#069:

| | GAME (before) | after |
|---|---|---|
| Row art | ❌ text only | ✅ the 7 transparent in-game icons (ASSETS.md §5.1) |
| Pass **OWNED** state | ❌ | ✅ `Owns_<key>`, default-to-not-owned |
| Live Hub price | ❌ hardcoded def | ✅ non-blocking `GetProductInfo` |

🔴 **Two of those are money-facing.** All three passes have **managed pricing** on the Hub, so Roblox can
move a price without touching our code — the game place was printing a number it might not charge. And
an owner of the 499 R$ Armored Boat still saw a live buy button, with only Roblox's own dialog to stop
the second purchase.

### TODO 0045 — Job #066 had already fixed this bug, on the *other* set of plates

The todo's hypothesis (`ArmoredHullL/R`) was right, and the reason is sharper than "it's a bare part":
**the boat has two sets of flank plating and only one of them was ever brought forward.**

```
L180  hullkit upgrade  — FIXED in Job 066
      4 tiled hullPlate segments, x ±7.1, Y 2.2, skinId "hullPlate"
L349  Armored Boat pass — untouched since Job 027
      ArmoredHullL/R  0.8 × 2.4 × 22, x ±7.4, Y 0.3, NO skinId
```

Three faults, and the third is the instructive one:

1. **x ±7.4** against a 14-wide (half-width 7) *modelled, curved* hull = 0.4 studs of clearance. It poked
   through the painted mesh.
2. **Y 0.3 is box-centre**, down near the waterline. The hull BOX is 3 tall but the mesh rises to ~4.5
   with its keel on the box bottom — the exact mistake #066 fixed by lifting the hullkit to Y 2.2.
3. **No `skinId` → no `Skin_hullPlate` child → `BoatPaint` could not see it.** Paint matches on skin
   *name*, so an unskinned part is **structurally unpaintable**. It was *guaranteed* to stay greybox grey
   beside a navy hull — not bad luck, and not fixable by changing its `Color`.

`BoatParts.Defs.hullPlate` even carries the lesson in a comment (*"a straight strip at constant beam
doesn't fit a hull that TAPERS, so the ends jutted out into open air like oars"*) — which is a
description of the armour plates as they stood.

## What shipped

### `plateBelt()` — one recipe, two callers

Both sets now go through one helper with the geometry as named constants (`PLATE_X 7.1`, `PLATE_Y 2.2`,
`PLATE_LEN 4.6` — the mesh's own modelled length; changing it stretches the art).

The pass reads as the heavier of the two by **wrapping further**, never by being taller or thicker —
both of those stretch the mesh and reintroduce the smeared-detail bug the tiling exists to prevent:

- the same **4-segment** flank run as the hullkit. Deliberately not more: that span is the one #066
  actually verified against the parallel midbody, and anything longer is a guess about where this hull
  starts to taper. Guessing about the taper is how the original slab ended up hanging in open air.
- plus **two bow shoulders** yawed 25° inboard, whose outboard offset *shrinks* as they go forward, so
  they follow the taper instead of ignoring it. Positions are derived from the yaw, so the shoulder's
  aft end stays butted against the belt's forward end if the angle is ever changed.

**`ArmoredProw` is deleted.** Its z −11 went stale when the hull grew 22 → 32 in #066, and it was
fighting the 8 × 8 `RampBow` for the same foredeck.

**Owning the hullkit AND the pass now builds ONE set** (the pass's). Two sets at the same x/Y would
z-fight, and "you own both" shouldn't look broken. `armored` is therefore decided at the top of `apply()`
rather than where the pass is handled, because the hullkit branch runs first and needs it.

⚠️ **Visual only — no stat change.** Hullkit's `MaxHP 150` and the pass's ×1.2 both still apply.

### The design system, ported byte-identical

`Theme` / `Components` / `UISound` / `UIBus` copied into `sync/ReplicatedStorage/UI/`.

**No per-file "this is a copy" header was added, on purpose.** A header would make
`diff -r lobby/sync/ReplicatedStorage/UI sync/ReplicatedStorage/UI` report a difference on every future
drift check, which someone then has to eyeball and dismiss. Keeping the files identical makes a silent
diff the whole check. The provenance note went into **one** line of `Theme`'s header instead — changed
**identically in both trees**, so byte-identity holds and the game copy no longer claims to be
"lobby tree only".

### The shop panel

`sync/.../UI/RobuxShop.local.luau` is now the lobby's, with **three intended differences**, each
commented in the file so a future diff against the lobby doesn't read as drift:

1. the kiosk remote is `OpenRobuxShop` (this place's own), not `OpenPanel`;
2. `DisplayOrder` raised 10 → **25**. The game place has a HUD stack the lobby doesn't, and at 10 the
   Salvage pill drew straight through the panel's scrim;
3. the panel **force-closes when the character goes `Downed`**. `DownedHud` is at 20, below this panel,
   so a shop left open would cover the bleed-out timer. Nothing in the lobby can down you.

### The kiosk

You editor-placed `Workspace.SpawnBase.Stands.RobuxShop` mid-job — the lobby station copied whole (same
mesh `81119390187013`, `Station` attribute, `Anchor`, `EntrySign`). `StartShopServer` now **finds it by
that attribute** and attaches the prompt, in the same `findStation`/`promptHost`/bounding-box-reach shape
`LobbyStations` uses. All of the part-building, billboard-building and raycast/`HubSpawn` positioning is
gone.

That deliberately retires Job #072's wreck-avoidance logic — a hand-placed hut cannot land inside a
hand-placed wreck. The cost is that a missing or renamed placement means no shop at all, so the lookup
warns loudly with the expected path rather than failing silently.

### Files changed

| File | |
|---|---|
| `sync/ReplicatedStorage/UI/{Theme,Components,UISound,UIBus}.luau` | **new** — the ported design system |
| `sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` | rebuilt on it (art + OWNED + live price) |
| `sync/ServerScriptService/Economy/StartShopServer.server.luau` | finds the editor station; builds nothing |
| `sync/ServerScriptService/Boat/BoatModules.server.luau` | `plateBelt()`; armour re-plated; prow removed |
| `sync/ServerScriptService/Cargo/CargoServer.server.luau` | MEDIC billboard removed |
| `sync/StarterPlayer/StarterPlayerScripts/UI/IntroHudGate.local.luau` | comments only — logic untouched |
| `lobby/sync/ReplicatedStorage/UI/Theme.luau` | the same one header line, to keep the copies identical |
| `ASSETS.md` | new §3.3; §3 index, §5 design-system note, §5.1, §2 `HullPlate` row + armour note |
| `../roblox.workspace/Assets/registry/meshes.md` | kiosk now in both places; `CollisionFidelity` warning |

## Three things that were wrong and got fixed

### 🔴 The kiosk was an invisible 20-stud cube — not in any todo

Your placement surfaced a defect nobody had filed: the hut imported with **`CollisionFidelity = Box`**.
On a 15 × 18.8 × 20 mesh that is a solid cube — the counter and the space under the eaves are sealed, so
you cannot walk up to the shop you are meant to walk up to.

Set to `PreciseConvexDecomposition` from the command bar (a **privileged** context — a runtime script
cannot write this property). Measured after: the collision surface sits **3.5–6.9 studs inside** the old
box on all four sides.

⚠️ **This is authoring-time and only persists if the place is SAVED** — see the manual step below.

### 🟠 My first read-back said the write had failed

The first `pcall` returned `ok=true` but re-reading `CollisionFidelity` in the same frame still said
`Box`. That looked like the silent capability gate. It wasn't — a control write to `RenderFidelity`
proved writes stick, and re-reading after a yield showed the new value. **Same-frame read-back of that
property is stale**; verify after a `task.wait`.

### 🟠 The first stinger check measured the wrong sound

Forcing `Phase = "night"` and scanning 3 s later found `morning_starts`, not `night_starts_2` — because
`DayNightServer` re-asserts `Phase` from `ClockTime` every heartbeat, so the flip was reverted inside the
wait and fired the *morning* stinger over it. Re-tested with a `DescendantAdded` hook that catches the
Sound the instant it is created.

## Verification (all in Play, 2026-08-02)

- [x] `[StartShop] ROBUX SHOP -> Workspace.SpawnBase.Stands.RobuxShop (reach 22)`
- [x] Shop opened via the **real kiosk remote**: **7 rows, 7 with art**, ids matching ASSETS.md §5.1
      exactly; all three passes read **OWNED**; gold packs stay live (repeatable products)
- [x] Layering measured, not eyeballed — every ambient HUD (`BoatHud`, `GoldHud`, `InventoryHud`,
      `DockShop`, `UntieButton`, `DownedHud`…) is **below** the panel at 25; only `ZoneBanner` 40,
      `RunGui` 50, `AdminPanel` 60, `IntroFade` 999 sit above, all correctly
- [x] Kiosk collision: raycasts hit **3.48 / 3.61 / 6.88 / 4.80 studs inside** the old AABB on the four
      sides — real geometry, not the box. *(An earlier `GetPartBoundsInBox` test was invalid: it is a
      broad-phase **bounds** query and reports the AABB regardless of fidelity.)*
- [x] Hut placement: **0 parts** intersect its volume; nearest `Plane` part **76 studs** away. The AABB
      "overlap" with the wreck was the oriented-box lie of Job #072 — checked, not assumed. `EntrySign`
      dead upright (0.0° tilt) and grounded
- [x] `[BoatModules] applied: fueltank, hullkit, motor2, searchlight, trailer, gunupgrade, ramps |
      ARMORED | paint: navy (12 parts)` — **hullkit AND the pass both owned**
- [x] **10 plates, 0 `HullPlate*`** — the supersede rule holds live. `ArmoredHullL`/`ArmoredHullR`/
      `ArmoredProw` all absent
- [x] Every plate at x ±7.10, **Y 2.20**, with a `Skin_hullPlate` child whose colour equals `Skin_hull`'s
      `(0.227, 0.306, 0.408)` **exactly** — fault 3 fixed and proven, not argued
- [x] Shoulders at x ±6.13, z −11.28, yaw ±25.0°
- [x] **Screenshotted from the side and the bow quarter** (the todo's "confirm visually" requirement):
      no dark slab, no poke-through, no step at the ends, shoulders follow the taper
- [x] Boat `BillboardGui` count **0**; `Medic Station` part still present
- [x] `night_starts_2` `75443344927115` — `IsLoaded` true, **11.0 s**, and caught firing + playing on a
      real night flip. The three dead ids appear nowhere in the live tree (**TODO 0044 re-confirmed**)
- [x] `diff -r` of the four UI modules across the trees — **silent**
- [x] `diff` of `MonetizationDefs` across the trees — **silent** (untouched)
- [x] `tools/luau-analyze.sh` **clean** over the whole GAME tree

> The LOBBY analyzer reports 4 diagnostics (`PilotIdle` ×3 `SameLineStatement`, `InventoryService`
> unknown require). **Pre-existing and untouched by this job** — the only lobby file changed here is one
> comment line in `Theme.luau`.

## ⚠️ The one manual step — save the place

**`CollisionFidelity` is set in the live Edit session but not yet saved.** It is an authoring-time
property: it lives in the place file, not in `sync/`, so nothing in git carries it. Verified still
`PreciseConvexDecomposition` in Edit after the Play round-trip.

**Save the place** or the kiosk goes back to being a 20-stud invisible cube on the next open.

## Out of scope — filed, not done

| Item | Why not here |
|---|---|
| Restyling the other 15 game HUD scripts | They are still hand-rolled greybox on raw `Color3`/`Enum.Font`. Its own job — but it no longer needs a design-system port first, which was the blocker |
| A shared package layer for the duplicated UI modules | Two separate Rojo trees with separate `default.project.json`s. Real work, and it would also want to absorb `MonetizationDefs`/`BoatParts`/`BoatPaint`, which have lived duplicated for many jobs |
| A game-place top bar / entry bar | The shop's `UIBus` route is wired and idle, waiting for one |
| Longer armour belt / distinct armour art | The flank run is held at the hullkit's verified 4 segments rather than guessed longer. If armour should read heavier still, the honest next step is measuring where this hull's midbody actually ends, or generating a dedicated armour mesh |
