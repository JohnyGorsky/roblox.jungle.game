# Job #116: Bunker — reusable door / lamp / alarm / loot script, unlocked by its generators

**Project**: `roblox.jungle`
**Created**: 2026-08-25 11:36:42
**Status**: ✅ Completed (see final-summary.md)

## Requirements / goal

User request: the end-zone bunker the user just placed becomes a **reusable, attachable system** (the same
shape as Job #115's `Generators`), so a later job can spawn bunkers anywhere and get identical behaviour.

Asked for, verbatim:

1. Doors start **closed** (`BunkerDoors`).
2. `LightLocation` carries a **pulsating lamp** — **RED = doors closed, GREEN = doors open**.
3. `ChestLocation` holds the loot — *"multiple golds there (6 separates so each player can take it, also
   each gold is for each player)"*.
4. The uploaded **`alarm`** sound (`103190295733089`) plays **when the doors open**.
5. When **all 3 connected generators are dead**: the lamp switches, the alarm fires, and the doors
   **tween ~10 s straight down into the ground**. Then the crew walks in and takes the loot.
6. The script must know **which generators** unlock a given bunker.

## Decisions taken with the user (wizard, 2026-08-25)

| Question | Answer |
|---|---|
| How the golds are shared | **One pile reserved per player, by name.** One pile spawns per crew member; only its named owner's prompt works |
| What each pile pays | **3 Gold + 150 Salvage** (a run's `finisher` objective pays 5 Gold; a rare camp nugget pays 1 Gold + 30 Salvage) |
| How a bunker finds its generators | **Siblings under the same parent** — every `Generator*` Model under the bunker Model's own parent. Zero config, and `EndBase.Bunker` is already laid out that way |
| What the gold looks like | **One `GoldChest` hero prop** on `ChestLocation` + **up to 6 `GoldNugget` piles** laid out in front of it, each its own prompt |

## Measured in Edit before writing anything (2026-08-25)

```
Workspace.EndBase.Bunker              Folder      <- the parent; also called "Bunker"
  Bunker              Model   36.89 x 25.00 x 38.48   <- the bunker; NO PrimaryPart
    BunkerDoors       Model   17.00 x 13.36 x  7.07
      BunkerDoors     MeshPart  pos (268.90, 28.84, 18353.69)  anchored, CanCollide, PreciseConvexDecomposition
    Bunker            MeshPart  the shell, pos (268.14, 30.53, 18362.09)
    LightLocation     Part  2.0 x 0.5 x 1.0  (274.83, 38.72, 18350.56)  invisible, CanCollide off
    ChestLocation     Part  2.0 x 0.5 x 1.0  (273.31, 22.24, 18365.58)  invisible, CanCollide off
    KeyPadLocation    Part  (280.51, 26.17, 18349.37)   <- NOT in this job's scope
    NumberLocation    Part  (259.78, 22.26, 18364.23)   <- NOT in this job's scope
  SpawnPoint2         Part   (310.00, 18.50, 18292.00)
  Generator1/2/3      Model  wired by Job #115           <- the three keys
```

- **Doors**: bottom y **22.16**, top y **35.52** → 13.36 of travel sinks them flush with the floor.
- **Interior floor** (cast against the shell mesh): y **22.10**. **Ceiling**: y **33.61** → 11.5 of headroom.
- **Terrain** under the whole bunker: y **18.00**; shell bottom y 18.03. So anything below 22.1 is inside
  the shell's own base, and anything below 18.0 is inside terrain — a 13.4-stud drop is fully hidden.
- **Doors face −Z**, toward the crew's approach (spawn 18292 → doors 18353 → chest 18365).
- **Space around `ChestLocation`** (from +3, against the shell): right wall **6.86**, left wall **16.05**,
  behind **7.62**, toward the doors **clear 40+**. So the hoard lays out *forward*, toward the doors.
- **`alarm` (103190295733089) is 8.05 s** — measured, not assumed. Against a 10 s slide it is a one-shot,
  not a loop: it covers the opening and leaves the last two seconds to the doors settling.
- **Library template** `ServerStorage.AssetLibrary.Structures.Bunker` already carries **all four markers**
  (`BunkerDoors`, `LightLocation`, `ChestLocation`, `KeyPadLocation`, `NumberLocation`), so a spawned
  bunker needs no extra editor work. ⚠️ `Structures.BunkerDoors` is a **separate, DOUBLE-size** copy
  (34 x 26.73 x 14.14) — the placed one is at half scale, so every offset must come from the model's own
  bounds, never a constant.
- Loot props exist already: `Props.GoldChest` (9.44 x 7.36 x 11.40 — Job #079 seats it at scale 0.65) and
  `Props.GoldNugget` (⚠️ a bare **MeshPart**, not a Model — 2.00 x 1.29 x 1.43).

## Constraints

- **GAME place only** (`sync/`). The lobby has no end zone.
- Job #115 already exposes the seam: `Generators.onDisabled(fn)` + a per-model `Disabled` attribute. This
  job consumes them and adds **no new code to the combat path**.
- ⚠️ **Three nested things are called `Bunker`** — a Folder, a Model, and a MeshPart. Name alone cannot
  identify a bunker; the signature is *a Model that contains a `BunkerDoors` child*.
- ⚠️ **Never set a PrimaryPart on the doors model.** A Model's PrimaryPart silently overrides `WorldPivot`,
  so the tween would move the doors by a different reference point than the one measured at attach.
- Asset bible + shared audio registry must record the `alarm` upload.

## Checklist

- [x] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** — NOT run: this session is instructed not to call the Agent tool
      unless asked, which overrides GROUND-RULES §8. Recorded in `final-summary.md` rather than skipped
      quietly; the six bugs were caught by read-back + screenshot in Play instead
- [x] N/A — new feature. Ground truth measured in Edit first (see above)
- [x] Implementation plan created & agreed (wizard, 2026-08-25)
- [x] Implementation completed
- [x] **Proof it works better** captured in PLAY — 2 of 3 generators moved the doors 0.000; the third
      fired the alarm, flipped the lamp green and dropped the doors 13.863 studs over 10 s; the share
      paid Gold 163→166 and Salvage 150→300; a run reset put the doors back to 22.167 exactly
- [x] Final summary + changelog written
