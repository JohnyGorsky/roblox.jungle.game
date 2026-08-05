# Implementation Plan — Job #077

**Project**: `roblox.jungle`
**Created**: 2026-08-05 · **Revised** 2026-08-05 to add camp ground materials + ambience (audio, VFX, lights)
**Status**: Planning — **assumptions A1–A4 approved by the user 2026-08-05**; awaiting build go-ahead.

## Approved assumptions

| | Assumption | Outcome |
|---|---|---|
| **A1** | Add camp practicals, **do NOT touch `AtmosphereRig.NIGHT`** | ✅ as proposed. Accepted consequence: the pools read weaker than §8 wants, because the night they sit in is still artificially lifted. The ambient drop stays a separate job, balanced against the searchlight and river navigation. |
| **A2** | The smoke column is a **gameplay signal**, sized to clear the band-3 canopy and be read from the river | ✅ as proposed. Verified from the boat at approach distance, not from beside the fire. |
| **A3** | Dirt on the desire line only | ❌ **CHANGED — user wants desire line *and* scattered patches.** Plan updated in Part 3, including the risk this accepts and the lever to pull if it reads as mush. |
| **A4** | Build order | ✅ **#076 first, then #077.** #076 sets the frame budget and owns the camp trees, so dressing camps first would mean re-dressing camps full of greybox trees. |

Companion to **[Job #076](../076/implementation-plan.md)** (terrain bands + foliage + river obstacles).
#076 owns the camp **trees**; #077 owns everything **built**, plus the camp's **ground and atmosphere**.

## Analysis

Every camp and dock in the game is coloured boxes. `ExcursionServer` builds two `Hut` blocks, up to three
tinted `LootCrate` cubes and an **eight-block hand-assembled trading post** (platform + counter + 4 posts +
a red fabric awning) with a **floating `BillboardGui`** for a sign; `DockServer` builds a 14×1×24 plank.
The `GoldNugget` is a **Neon cube**. The camp floor is **one flat `Grass` fill**. There is **no camp audio,
no camp VFX and — measured live — zero `Light` objects in the entire Workspace.**

**Every model swap here is cosmetic.** No loot rule, economy value, spawn count, guard count or prompt
behaviour changes. The ambience additions are new, but additive — nothing existing changes behaviour.

**Assets are all in hand.** Nothing waits on sourcing (`ASSETS.md` §3.5).

### The one thing that isn't a straight swap

`Tent` is **43×13×34 studs**. The `Hut` block it replaces is **10×8×10**. The stilt huts are 20–40 studs
across. So the hardcoded offsets (`campPos + (-12, 4, 10)`, `(13, 3, 4)`) cannot survive — at those
spacings the new models intersect each other and the loot. **The layout must be re-derived regardless**,
which is why "re-dress properly" was the cheap answer rather than the ambitious one.

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
| — (new) | — | **campfire** from `RockA/B/C` + `LogMossy` + VFX | ~8 |

### Part budget

Camps stream with the boat, so **1–2 are live at once**, not eleven:

| Per camp | Instances |
|---|---|
| `Tent` + `BahayKubo5` | 14 |
| 3 × `Barrel` + 1 `CrateWood` | 84 |
| campfire (3 rocks + 2 logs + VFX + light) | ~10 |
| `SandbagWall` ×3 | 3 |
| `RangerTower` (landings only) | 128 |
| **subtotal** | **~240** |
| trading village adds `BahayKubo7` | +95 |
| `Dock` | +62 |

**~300–400 live**, against Job #076's ~5,560 foliage. **Under 7% of the scene** — camps are not the perf
risk. It also answers the `CrateWood` worry: one hero crate per camp instead of three is 84 instances
rather than 198.

## Part 2 — Camp layout (re-dressed)

Same `campPos`, same footprint radius, same guard spawn ring — only the arrangement changes:

```
              ▲ BahayKubo5            ▲ Tent
              (sleeping hut)          (supply tent)
                     \                /
                      \   (◍) fire   /       ← campfire: light + smoke + crackle
                       \            /
        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓            ← SandbagWall ×3, facing the path
        ■ Barrel  ■ Barrel  ▣ CrateWood      ← loot behind cover
                                              (▣ = the hero crate)
                  ♠   ♠   ♠                   ← guards, unchanged spawn ring
        ═════════════════════════════         ← Ground: worn dirt path
                  ↑ path in from the dock
```

Rules the layout follows, so it is derived rather than hand-tuned per camp:

- **Everything faces the approach.** The path from the dock is a known direction
  (`campPos - dockPos`), so tents face it, sandbags sit between it and the loot, and guards keep their
  existing ring. A camp you walk into from behind is a camp you can't read.
- **Loot behind cover.** Cover between the player and the crates is what makes guards matter — a layout
  change that does real gameplay work rather than dressing.
- **The fire is the centre.** Placed first; everything else positioned relative to it.
- **Footprints are measured, not assumed.** Offsets come from each model's `GetExtentsSize()` plus a gap,
  so swapping `BahayKubo5` for `BahayKubo1` later cannot make them intersect.

Trading villages already differ in code (only some docks are landings; only villages get a post). The
dressing makes that legible: a village gets `BahayKubo7` + the sign + more barrels; a plain camp gets one
tent and the survival treatment. Same code path, different table.

## Part 3 — Camp ground: LeafyGrass + dirt patches

**Today it is one flat fill.** `ExcursionServer:110`:

```lua
Terrain:FillBlock(CFrame.new(cx, CLEAR_Y - 20, cz), Vector3.new(size, 40, size), Enum.Material.Grass)
```

One material over the whole basin — exactly what STYLEGUIDE §4 forbids: *"never flat-coloured — mix sand,
dirt, mud, grass patches."*

**After**, the basin floor is painted in a second pass over the same region:

| Material | Where | Why |
|---|---|---|
| **`LeafyGrass`** | the basin default | deeper, darker, more overgrown than `Grass` — it reads as jungle floor rather than lawn, and it's what you asked for |
| **`Grass`** | noise-driven patches | breaks the LeafyGrass up so it isn't one flat tone either |
| **`Ground`** (dry dirt) — *deliberate* | **the path from the dock to the camp**, and a **trampled ring around the fire and under the tents** | dirt where people walk. Environmental storytelling, not texture variety: bare earth is the evidence someone lives here |
| **`Ground` / `Mud`** — *scattered* | noise-driven patches through the rest of the basin | **approved A3:** the ground never repeats, so it doesn't read as a painted-on path over a clean lawn |
| **`Mud`** | a band where the basin meets the water | per §4's mix; the bank shouldn't be the same tone as the interior |

**Two dirt passes, and the order matters.** Scattered patches are painted **first** at low weight, then the
desire-line path and the trampled rings go **on top** at full weight. If it were the other way round the
random patches would eat holes in the path.

> ⚠️ **The risk A3 accepts, so it can be watched for:** surrounding the path with other bare patches can
> make the path itself read as *less* deliberate — the navigational hint you get on landing is weaker if
> everything is patchy. Mitigation is contrast, not restraint: scattered patches stay **small and sparse**
> (low noise threshold), the path stays **wide and continuous**. If it reads as mush in the playtest, the
> lever is the scatter weight, not the path.

**No new terrain writes.** The existing `FillBlock` already covers the region; this is a paint pass over
the same voxels in the same function — one extra pass at camp build time and **zero at runtime**.

⚠️ **`CLEAR_Y` is `WATER_Y + 3`** and the basin is carved flat. The `Mud` band must stay above the water
line or it will read as a muddy pool rather than a bank.

## Part 4 — Camp audio

Follows the rule `GameSoundscape` sets out: **positional world cues live on their part; only 2D interface
sound goes through `UISound`.** All of these are `Sound` objects parented to geometry with rolloff — none
of them touch the global bed.

| Cue | Asset | Where | Notes |
|---|---|---|---|
| **Campfire crackle** | `crackle-campfire` `113774133604878` | on the fire's centre part | Already owned, wired in the lobby, **unwired in the game place**. Looping, `RollOffMaxDistance` ~60 so it fades before the next camp. |
| **Water lapping** | `water-splashes` `115704936377395` | on the dock deck | `GameSoundscape` already places this positionally at the dock — extend to camp docks rather than duplicating. |
| **Rope creak** | `rope_creak` | on the dock's tie point, **only while the boat is tied** | Ties to a state the player caused. Idle creak with no boat is noise. |
| Night insects | `cicadas` | — | **No per-camp work.** `GameSoundscape` already runs cicadas as a global crossfading night bed. |

> ⚠️ **Do not fire `cicadas` per camp as a one-shot.** `GameSoundscape`'s header records this measured
> lesson: the clip is **71.4 s long**, so one-shots stack — the plan that fired them every 6–16 s would
> have layered six or seven concurrent 71-second loops into a wall of noise. It is a bed, and it already
> exists.

## Part 5 — Camp VFX

Built as pooled, palette-tinted, distance-culled templates per STYLEGUIDE §8, and **budget-capped by
construction** — a per-camp cap, not "one emitter per prop".

| Effect | What | Why |
|---|---|---|
| **Fire + embers** | `Fire` + a small ember `ParticleEmitter` rising off the logs | the fire has to look alive at 3 studs and at 60 |
| **Smoke column** | `Smoke`, tall and thin, tinted grey-warm | **This one earns its place on gameplay, not looks:** a smoke column visible from the river tells the driver a landing is coming — the same job `RangerTower` does, at eye level. Nothing currently signals a camp from the water. |
| **Fireflies** | `ParticleEmitter`, warm amber, slow drift, **night only** | §8 names fireflies explicitly. Gated on `Workspace.Phase == "night"` so they cost nothing by day. |
| **Dust / pollen motes** | `ParticleEmitter`, drifting, **day only** | sells warm shafts of light through the canopy; the day counterpart to fireflies |

**No new assets** — all four are `ParticleEmitter`/`Fire`/`Smoke` configured in code, tinted from
`Theme.color`.

## Part 6 — Camp lights, and a conflict that must be handled

**`Planned/camp-night-practicals.md` is exactly this request**, and it already did the measurement:

- **0 `Light` objects in the entire Workspace.**
- `LightController` **already switches anything tagged `NightLight`** at dusk (17.5 h) and dawn (6.5 h).
  It works; it has nothing to switch. The only `NightLight`s in the game are *carried* — player torch and
  boat searchlight.

So the wiring exists. Adding lights means placing them and tagging them `NightLight`.

| Light | Where | Tag |
|---|---|---|
| Warm flickering `PointLight` | the campfire | `NightLight` |
| Warm amber `PointLight` ×2–3 | along the sandbag line and at the dock head | `NightLight` |
| Warm internal glow | inside the tent / stilt hut | `NightLight` |

> ### ⚠️ THE CONFLICT — read before implementing
>
> `camp-night-practicals.md` records that Job #073's night palette is **deliberately propped up** —
> `outdoorAmbient (66,76,96)`, `exposure 0.26`, `envDiffuse 0.85` — *purely because there are no
> practicals*. The first attempt used values consistent with a properly-lit camp and the screenshot came
> out **effectively pitch black**.
>
> That planned job's scope says the two changes **must land together**: add practicals *and* bring
> `AtmosphereRig.NIGHT` back down, or night either stays flat or goes black.
>
> **But that reasoning was written for the spawn base, and it does not transfer to the river.** The camps
> are **6 spots on an 18,000-stud river**. Lowering the *global* night ambient to suit a lit camp would
> make **the other 17,000 studs of river unnavigable** — and the river at night is a core gameplay beat
> (`EnemyServer` scales sea threat by `Phase`).
>
> **So this job adds camp practicals and does NOT touch `AtmosphereRig.NIGHT`.** The consequence, stated
> honestly: the camps will be *lit* but the pools will read weaker than they should against a night that
> is still lifted. Getting the full §8 "warm pools in real darkness" effect needs the ambient drop, and
> that has to be balanced against the boat searchlight and the river — which is its own job, not a
> side-effect of this one. **This is assumption A1 below.**

## Part 7 — The sign

The floating `BillboardGui` goes. STYLEGUIDE §5 is explicit that world signage is *physical* and uses
`Theme.font.sign` (`SpecialElite`), not screen UI — and an `AlwaysOnTop` billboard renders **through the
terrain and through the hut**, the same class of bug Job #072 hit with world tags visible from the plane.

Replacement: `WelcomeSign` geometry + a `SurfaceGui` on its face, `Theme.font.sign`, cream on wood.
Readable from the water, occluded correctly by the world.

## Part 8 — What must not change

Verified against the code, because this is where a cosmetic job quietly breaks a system:

| Thing | Where | Why it matters |
|---|---|---|
| `LootPrompt` + `Triggered` → `pickupLoot` | `:232-243`, `:253-264` | the only way loot is collected |
| `Resource` / `Kind` / `Id` attributes | `:231`, `:252` | `pickupLoot` reads them to decide what you get |
| `NuggetPrompt` + `NuggetsSpawned` cap | `:86-95` | the Gold economy; `NUGGET_CAP` 3/run |
| `CarriedCrate` **`Massless = true`** | `:190` | welded to your root — a heavy prop changes how you move while hauling |
| `CarriedCrate` `CanCollide = false` | `:189` | else it collides with the world over your head |
| Dock `TieSpot` Attachment position | `DockServer` | `StagingServer` + `DockServer` tie/untie depend on it |
| Guard spawn positions + count | `:246-248` | difficulty scaling by crew size (Job #058) |
| `CLEAR_Y` basin height | `:55` | guard anchors and every prop's Y derive from it |

⚠️ **`Dock.PlacePlace` is not dock geometry** — it is the plane's fly-in marker 500 studs west at X −760.
Job #072 learned this when including it inflated a bounding box from 681 to 845 studs. Anything measuring
the dock must exclude it.

⚠️ **All camp props `Anchored`, none colliding with the boat.** `RiverBootstrap`'s standing rule: physical
collision with the boat assembly blows it up.

## Part 9 — Files

**New**
| File | Purpose |
|---|---|
| `sync/ServerScriptService/World/CampDefs.luau` | the dressing table — models, layout slots, which camps are villages, ground-material weights, VFX/light budgets. **The one place a camp's contents are listed.** |
| `sync/ServerScriptService/World/Campfire.luau` | builds the rock-ring + crossed-logs + Fire/Smoke/embers/PointLight/crackle unit, so the lobby recipe exists once in code |
| `sync/ServerScriptService/World/CampAmbience.luau` | the per-camp VFX + positional audio + `NightLight` placement, pooled and capped |

**Edited**
| File | Change |
|---|---|
| `ExcursionServer.server.luau` | dressing from `CampDefs`; ground paint pass; crates/nugget/carried crate use real models; calls `Campfire` + `CampAmbience` |
| `DockServer.server.luau` | real `Dock` model; `TieSpot` re-anchored to the model's deck; water + rope audio |
| `ASSETS.md` | §3.5 written; flip statuses to ✅ on completion |
| `Planned/camp-night-practicals.md` | mark the camp half delivered; the `AtmosphereRig.NIGHT` half stays open (see A1) |

**Untouched:** enemies/guards (Meshy work, own job), the boat, the HUD, `RiverBootstrap` (#076), the
hand-built spawn base, **`AtmosphereRig`** (see A1).

## Part 10 — Order of work

1. `CampDefs` + `Campfire` + `CampAmbience` — the data and the two new buildables.
2. **Dock first** — one model, one call site, easiest to verify tie/untie still works.
3. Crates + nugget + carried crate — the prompt-bearing objects, so the loot flow is tested early.
4. Ground paint pass — cheap, visible, independent of the props.
5. Camp re-dress — tents, stilt huts, sandbags, fire, tower.
6. Ambience — VFX, positional audio, night lights.
7. Trading village — `BahayKubo7` + the physical sign.
8. `ASSETS.md` + `Planned` bookkeeping.

Steps 2–4 are independently shippable; if the re-dress needs another pass, the dock, loot and ground still
stand alone.

## Part 11 — Verification

- **Ride to a landing, tie up, go ashore, raid, haul back, untie** — the whole loop, because the whole
  loop touches something this job changed.
- **Loot still works**: each crate grants its resource, kind-crates still grant the gun/ammo, the nugget
  still increments Gold and respects `NUGGET_CAP`.
- **Hauling still feels the same** — `CarriedCrate` `Massless`, no collision over your head.
- **Tie/untie at the real dock**, plus the `UntieButton` path from Job #075.
- **Nothing collides with the boat** — drive into the dock and the camp shore; the boat survives.
- **Ground reads as jungle floor**, and the dirt path is legible as a path rather than as noise.
- **Night pass**: fire is the warm centre, fireflies present, `NightLight`s switch at 17.5 h, sign is
  occluded by the hut rather than glowing through it. Screenshot day and night.
- **Smoke column visible from the water** at approach distance — this is the gameplay claim, so it gets
  tested from the boat, not from beside the fire.
- **Audio**: crackle fades out before the next camp; no cicada stacking; rope creak only while tied.
- **Instance count** ashore, against the ~300–400 estimate.
- **Device Emulator** with #076's foliage live — both spend the same frame, and particles are the usual
  mobile casualty.
- `tools/luau-analyze.sh` clean.

> ⚠️ **The place file must be saved.** `BahayKubo1/2/5/7` and `GoldNugget` live in the game place's
> `ServerStorage.AssetLibrary`, which is **not** a Rojo-synced path — they exist only in the `.rbxl`.
> Without a save, a fresh clone has the code but not the models.
