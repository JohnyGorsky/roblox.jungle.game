# Implementation Plan — Job #077

**Project**: `roblox.jungle`
**Created**: 2026-08-05
**Status**: Planning (awaiting go-ahead)

Companion to **[Job #076](../076/implementation-plan.md)** (terrain bands + foliage + river obstacles).
#076 owns the camp **trees**; #077 owns everything **built**.

## Analysis

Every camp and dock in the game is coloured boxes. `ExcursionServer` builds two `Hut` blocks, up to three
tinted `LootCrate` cubes and an **eight-block hand-assembled trading post** (platform + counter + 4 posts
+ a red fabric awning) with a **floating `BillboardGui`** for a sign; `DockServer` builds a 14×1×24 plank.
The `GoldNugget` is a **Neon cube**.

**Every swap in this job is cosmetic.** No loot rule, economy value, spawn count, guard count or prompt
behaviour changes. That is the property that makes it reviewable: if a run plays differently afterwards,
something is wrong.

**Assets are all in hand** — nothing waits on sourcing (§3.5 of `ASSETS.md`).

### The one thing that isn't a straight swap

`Tent` is **43×13×34 studs**. The `Hut` block it replaces is **10×8×10**. The stilt huts are 20–40 studs
across. So the existing hardcoded offsets (`campPos + (-12, 4, 10)`, `(13, 3, 4)`) cannot survive — at
those spacings the new models intersect each other and the loot crates. **The layout has to be re-derived
regardless**, which is why "re-dress properly" was the cheap answer rather than the ambitious one.

---

## Part 1 — The swap table

| Greybox | Built at | Becomes | Instances |
|---|---|---|---|
| `Hut` ×2 (10×8×10, 8×6×8) | `ExcursionServer:227-228` | `Tent` + `BahayKubo5` | 1 + 13 |
| `LootCrate` (resource, tinted) | `:230` | **`Barrel`** | 6 each |
| `LootCrate` (kind-crate, Metal) | `:251` | **`AmmoBox`** | 22 |
| hero crate (1 per camp, new) | — | **`CrateWood`** | 66 |
| `TradingPost` 8-block stall | `:274-281` | **`BahayKubo7`** | 95, once per village |
| `ShopSign` invisible part + `BillboardGui` | `:283-300` | physical sign from `WelcomeSign` | 4 |
| `GoldNugget` Neon cube | `:86` | **`GoldNugget`** mesh | 1 |
| `CarriedCrate` (welded over your head) | `:185` | **`Barrel`**, scaled | 6 |
| `tree()` trunk+canopy ×45 | `:268-271` | **Job #076's band picker** | — |
| Dock `Deck` plank | `DockServer:55` | **`Dock`** | 62 |
| — (new) | — | **`RangerTower`** at the 6 landings | 128 |
| — (new) | — | **campfire**, built from `RockA/B/C` + `LogMossy` | ~8 |

### Part budget

Camps stream with the boat, so **1–2 are live at once**, not eleven:

| Per camp | Instances |
|---|---|
| `Tent` + `BahayKubo5` | 14 |
| 3 × `Barrel` + 1 `CrateWood` | 84 |
| campfire (3 rocks + 2 logs + VFX) | ~8 |
| `SandbagWall` ×3 | 3 |
| `RangerTower` (landings only) | 128 |
| **subtotal** | **~237** |
| trading village adds `BahayKubo7` | +95 |
| `Dock` | +62 |

**~300–400 live**, against Job #076's ~5,560 foliage. **Under 7% of the scene** — camps are not the perf
risk, and the earlier worry about `CrateWood` at 66 parts is answered by using it once per camp instead of
three times (84 instances instead of 198).

## Part 2 — Camp layout (re-dressed)

Same `campPos`, same footprint radius, same guard spawn ring — only the arrangement changes:

```
              ▲ BahayKubo5            ▲ Tent
              (sleeping hut)          (supply tent)
                     \                /
                      \    ( ) fire  /        ← campfire between them
                       \            /
        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            ← SandbagWall ×3, facing the path
        ■ Barrel  ■ Barrel  ▣ CrateWood      ← loot behind cover
                                              (▣ = the hero crate)
                  ♠   ♠   ♠                   ← guards, unchanged spawn ring
        ─────────────────────────────
                  ↑ path in from the dock
```

Rules the layout follows, so it is derived rather than hand-tuned per camp:

- **Everything faces the approach.** The path from the dock is a known direction
  (`campPos - dockPos`), so tents face it, sandbags sit between it and the loot, and guards keep their
  existing ring. A camp you walk into from behind is a camp you can't read.
- **Loot behind cover.** Cover between the player and the crates is what makes guards matter — it is a
  layout change that does real gameplay work rather than dressing.
- **The fire is the centre.** Placed first; huts positioned relative to it. At night it is the only warm
  light for hundreds of studs, and STYLEGUIDE §8 wants night to be *"warm pools of light, never evenly
  lit."*
- **Footprints are measured, not assumed.** Offsets come from each model's `GetExtentsSize()` plus a gap,
  so swapping `BahayKubo5` for `BahayKubo1` later cannot make them intersect.

### Trading villages differ from plain camps

`ExcursionServer` already distinguishes them (only some docks are landings, and only villages get a
trading post). The dressing makes that legible: a village gets `BahayKubo7` + the sign + more barrels; a
plain guarded camp gets one tent + the survival-camp treatment. Same code path, different table.

## Part 3 — The sign

The floating `BillboardGui` goes. STYLEGUIDE §5 is explicit that world signage is *physical* and uses
`Theme.font.sign` (`SpecialElite`), not screen UI — and an `AlwaysOnTop` billboard renders **through the
terrain and through the hut**, which is the same class of bug Job #072 hit with world tags visible from
the plane.

Replacement: `WelcomeSign` geometry with a `SurfaceGui` on its face, `Theme.font.sign`, cream on wood.
Readable from the water, occluded correctly by the world.

## Part 4 — What must not change

Verified against the code, because this is where a cosmetic job can quietly break a system:

| Thing | Where | Why it matters |
|---|---|---|
| `LootPrompt` + its `Triggered` → `pickupLoot` | `:232-243`, `:253-264` | the only way loot is collected |
| `Resource` / `Kind` / `Id` attributes | `:231`, `:252` | `pickupLoot` reads them to decide what you get |
| `NuggetPrompt` + `NuggetsSpawned` cap | `:86-95` | the Gold economy; `NUGGET_CAP` 3/run |
| `CarriedCrate` **`Massless = true`** | `:190` | it is welded to your root — a heavy prop changes how you move while hauling |
| `CarriedCrate` `CanCollide = false` | `:189` | otherwise it collides with the world over your head |
| Dock `TieSpot` Attachment position | `DockServer` | `StagingServer` + `DockServer` tie/untie depend on it |
| Guard spawn positions + count | `:246-248` | difficulty scaling by crew size (Job #058) |

⚠️ **`Dock.PlacePlace` is not dock geometry** — it is the plane's fly-in marker parked 500 studs west at
X −760. Job #072 learned this when including it inflated a bounding box from 681 to 845 studs. Anything
here that measures the dock must exclude it.

⚠️ **All camp props must be `Anchored`**, and none may collide with the boat. `RiverBootstrap`'s comment
is the standing rule: physical collision with the boat assembly blows it up.

## Part 5 — Files

**New**
| File | Purpose |
|---|---|
| `sync/ServerScriptService/World/CampDefs.luau` | the dressing table: which models, which layout slots, which camps are villages. **The one place a camp's contents are listed.** |
| `sync/ServerScriptService/World/Campfire.luau` | builds the rock-ring + crossed-logs + VFX fire from `AssetLibrary`, so the lobby recipe exists once in code |

**Edited**
| File | Change |
|---|---|
| `ExcursionServer.server.luau` | camp/village dressing from `CampDefs`; crates, nugget, carried crate use real models; the `block()` helper survives only for anything genuinely still greybox |
| `DockServer.server.luau` | real `Dock` model; `TieSpot` re-anchored to the model's own deck |
| `ASSETS.md` | §3.5 already written; flip statuses to ✅ on completion |

**Untouched:** enemies/guards (Meshy work, own job), the boat, the HUD, `RiverBootstrap` (that's #076),
the hand-built spawn base.

## Part 6 — Order of work

1. `CampDefs` + `Campfire` — the data and the one new buildable.
2. **Dock first** — one model, one call site, easiest to verify tie/untie still works.
3. Crates + nugget + carried crate — the prompt-bearing objects, so the loot flow gets tested early.
4. Camp re-dress — tents, stilt huts, sandbags, fire, tower.
5. Trading village — `BahayKubo7` + the physical sign.
6. ASSETS.md statuses.

Steps 2–3 are independently shippable; if the camp re-dress needs another pass, the dock and loot swaps
still stand on their own.

## Part 7 — Verification

- **Ride to a landing, tie up, go ashore, raid, haul back, untie.** The whole loop, because the whole
  loop touches something this job changed.
- **Loot still works**: each crate grants its resource, the kind-crates still grant the gun/ammo, and the
  nugget still increments Gold and respects `NUGGET_CAP`.
- **Hauling still feels the same** — `CarriedCrate` `Massless`, no collision over your head.
- **Tie/untie at the real dock**, plus the `UntieButton` path from Job #075.
- **Nothing collides with the boat** — drive into the dock and the camp shore, confirm the boat survives.
- **Night check** — the campfire should be the only warm light at the camp, and the sign should be
  occluded by the hut rather than glowing through it.
- **Instance count** sampled ashore, against the ~300–400 estimate.
- **Device Emulator** with #076's foliage live, since both spend the same frame.
- `tools/luau-analyze.sh` clean.

> ⚠️ **The place file must be saved.** `BahayKubo1/2/5/7` and `GoldNugget` live in the game place's
> `ServerStorage.AssetLibrary`, which is **not** a Rojo-synced path — they exist only in the `.rbxl`.
> Without a save, a fresh clone of this repo has the code but not the models.
