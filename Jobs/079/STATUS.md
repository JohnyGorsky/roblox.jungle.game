# Job #079 — STATUS / session handoff

> ⚠️ **SUPERSEDED 2026-08-16 — the job is COMPLETE.** Read
> [`final-summary.md`](final-summary.md) instead. Everything below was written mid-job, before the three
> GLBs were imported and wired; §3 ("NEXT STEP — import 3 models") is **done**, and its guess that
> `GoldChest` would become camp hero loot turned out to be **wrong** (the hero slot is a resource crate
> carrying Gasoline/Metal/Ammo — the chest is trading-post dressing instead). Kept for the history.

---

# (superseded) Job #079 — STATUS / session handoff (2026-08-16)

**Project**: `roblox.jungle` · **Job**: #079 Axe melee weapon → grew to *all four held items* + all weapon audio

> Written for a cold session restart. Read this first, then `intake.md`, then `asset-shopping-list.md`.

---

## TL;DR — where things stand

| | |
|---|---|
| **Job #079 code** | ✅ **Complete and verified in Play.** All four held items are real models with real audio. |
| **Bookkeeping** | ❌ `final-summary.md` + `changelog.md` **not written yet** — the only thing left on the job itself. |
| **Working tree** | 3 modified files + 3 new GLBs, **uncommitted**. See "Uncommitted work" below. |
| **Blocking the next step** | 3 GLBs need a **Studio import by you**, then I do the measured pass. |
| **⚠️ Do not forget** | **Save the place.** Every weapon/creature model lives in `ServerStorage`, which is **not Rojo-synced** — it exists only in the `.rbxl`. |

---

## 1. What shipped in #079

All four held items were greybox coloured Parts. None are now.

| Item | Model | Sound | Animation |
|---|---|---|---|
| **Axe** (starting weapon) | rebuilt from Defender's ids — mesh `145815658` / texture `186913315` / decal `4657174543` | `AxeSwing` `210946558` · `AxeChop` `8936215056` · `Equip` `2304904662` | `slash1` `567480700` / `slash2` `567479941`, alternating |
| **Pistol** | Meshy → `AssetLibrary.Weapons.Pistol`, scale `0.316`, yaw `+90°` | `fire` `138178318678571` · `empty` `75733077651437` | — |
| **Shotgun** | Meshy → `AssetLibrary.Weapons.Shotgun`, scale `0.421`, yaw `+90°` | `fire` `129597576449946` · `pump` `113837896417526` · `empty` `75733077651437` | — |
| **Torch** | **built in code**, not sourced — stick + `Fire` + embers + `PointLight` | crackle `113774133604878` | — |
| **Boat turret** *(not a held item, but same audio file)* | existing `GunBarrel` | `fire` `138178318678571` · `empty` `135106168511714` · `reload` `134765294816468` | — |

### Two things worth remembering about *why*

- **Orientation was measured, not eyeballed.** Both Meshy guns are authored barrel-along-**+X**; the
  greybox they replace pointed **−Z**. Hence `BARREL_X_TO_MINUS_Z = 90` in `WeaponAssets.luau`. This was
  proved by profiling mesh height along X (pistol: 2.02 studs tall at x=−1.22, 0.12 at x=+1.82). The
  crocodile in #078 taught this lesson the expensive way — **never infer facing from a screenshot.**
- **One Sound, restarted — never one per bullet.** Fire intervals are 0.22 s / 0.7 s; a `Sound` per shot
  stacks into noise (the trap `GameSoundscape` documents for the cicadas). `WeaponServer` and `GunServer`
  both build their cues **once** and restart them.

### The turret audio was the last real gap (done 2026-08-15)

Handhelds were already wired; the mounted turret had **no audio at all**, and `gun_reload` had nowhere to
play because handheld guns have no magazine. The turret is the only weapon in the game with a real reload
moment — it swallows an `Ammo` crate from boat cargo when it runs dry.

**Verified live in Play:** 12 shots → `fire=1 reload=1 empty=0` (crate consumed, Ammo 1→0), then drained
the turret → `empty` fired 3 times. Not inferred — read off the console.

---

## 2. Uncommitted work in the tree

```
 M ASSETS.md
 M sync/ServerScriptService/Combat/GunServer.server.luau     ← turret audio wiring
 M sync/ServerStorage/Inventory/WeaponAssets.luau            ← WeaponAssets.TURRET added
?? assets/GameObjects/Shop/GoldChest.glb                     ← new, needs import
?? assets/Objects/Ambient/Lantern.glb                        ← new, needs import
?? assets/Objects/Ambient/LogJam.glb                         ← new, needs import
?? assets/Objects/Ambient/{Lantern,LogJam}_textures/
```

Last commit on `main`: `82305c0 Updated assets`. **I do not commit — that is yours.**

State checks run before this handoff: script analyzer clean; both `Theme.luau` copies byte-identical
(`sync/ReplicatedStorage/UI/` and `lobby/sync/ReplicatedStorage/UI/` — they are identical **by contract**).

---

## 3. ⏭️ NEXT STEP — import 3 models

Generated 2026-08-15 (90 credits: 3 × `text_to_3d` meshy-6 + refine). Balance **1660 → 1450**.

> ⚠️ **The first download of Lantern and LogJam silently failed** — the API reported success and wrote the
> `_textures/` folders, but no `.glb` landed. Re-downloaded 2026-08-16 and **verified on disk**:
> `GoldChest.glb` 31 M · `Lantern.glb` 19 M · `LogJam.glb` 31 M. If a Meshy download ever "succeeds",
> `ls` the file — do not trust the tool result alone.

| GLB on disk | Import as | Put it under | What it is for |
|---|---|---|---|
| `assets/GameObjects/Shop/GoldChest.glb` | `GoldChest` | `ServerStorage.AssetLibrary.Shop` | the Robux buy-popup art — currently greybox |
| `assets/Objects/Ambient/Lantern.glb` | `Lantern` | `ServerStorage.AssetLibrary.Props` | lobby lanterns (ASSETS.md §1: signpost built, *"Lanterns still ▫"*) |
| `assets/Objects/Ambient/LogJam.glb` | `LogJam` | `ServerStorage.AssetLibrary.Props` | river blockage set-piece |

**Import steps** (same as the guns):
1. Studio → **Import 3D** → pick the `.glb`
2. Name it **exactly** as the table says
3. Parent it under the listed `ServerStorage.AssetLibrary` group
4. ⚠️ Set **`CollisionFidelity = PreciseConvexDecomposition`** on the MeshParts — imports default to `Box`,
   which makes players bump into empty air around a log jam
5. **Save the place**

Then tell me, and I do the **measured pass**: profile the mesh for real size + facing, pick the scale
against whatever it replaces, and wire it. Same procedure as Pistol/Shotgun — **measured, not guessed.**

---

## 4. What Last River still needs (corrected list)

Full detail in `Planned/asset-gaps.md`. Summary, in the order worth doing:

| # | Gap | Count | Source | Note |
|---|---|---|---|---|
| 1 | **HUD icons** | **16** | Flaticon | ⚠️ **same author as the §1.9 lobby set** — mixed packs are the #1 way an icon set looks wrong |
| 2 | **HUD sounds** | **5** | Pixabay → upload | `lowFuel` · `lowHull` · `downed` · `revived` · `runLost` — the moments a run turns, currently silent |
| 3 | Audio on disk, never uploaded | ~6 | upload | `boat_destroyed` · `boat_on_fire` · `metal_debris` · 3 boat-engine files ⚠️ **check the engine files for duplicates of the wired loop first** |
| 4 | Boat upgrade models | 6 | Meshy | ⚠️ **`trailer` = cargo ON the rear deck, NOT a towed barge** |
| 5 | World set-pieces | — | mixed | waterfalls (terrain + VFX, **not** Meshy work) · zone dressing (**needs a spec first**) · river ramps (**needs a design decision**) · plane-crash intro (2D art) |

### ✅ Closed / corrected — do not re-raise these

- **Boat upgrade *purchasing*** — you corrected me: *"bot upgrade already exists, we did it in lobby."*
  `BoatParts` holds 18 real MeshParts, named by art rather than module id, which is why my sweep missed
  them. ASSETS.md is corrected. Only the 6 models in row 4 above are still greybox.
- **Anaconda** — skipped by your decision; the existing creature is reused as-is.
- **All 6 creatures** (Job #078) and **all 4 held items + weapon audio** (Job #079) are done.

### ⚠️ The 16 empty icon ids are the tracking mechanism — do NOT "fix" them by reuse

I tried this on 2026-08-15 and **reverted it the same day.** `Theme.iconFallback` already maps every empty
key to a semantically-close wired icon, and `Components.iconId` substitutes automatically. The file says so
in its own words:

> *"semantically close enough to read correctly in a screenshot, never so close that we forget to replace
> it."*

Filling the ids removes the boot warning, makes a deliberately-imperfect stand-in permanent, and duplicates
a system that already works. **"The axe icon looks wrong" is this working as designed** — the axe slot draws
the `tools` wrench because no blade glyph exists among the 23 wired icons. That one genuinely needs art.

> ⚠️ When the icon art lands: **rename `machete` → `axe`.** #079 made the starting melee an axe, and
> `Theme.itemIcon.Axe` currently points at the `machete` key **in both trees**.

---

## 5. Open decisions / known deferrals

### The white flying object — FIXED

It was `MeleeClient`'s `SwingFx`: a cream Neon slab left in as a Job #075 placeholder. Removed; the real
axe swing animation replaces it.

### The shelf artifact — DEFERRED, needs your call

No land may sit between `WATER_Y` and `WATER_Y + 8` or it reads as a shelf. But `RiverGenerator` ramps the
bank from **exactly** the waterline, and `FoliageServer.MIN_GROUND_Y_ABOVE_WATER = 1`. Fixing it properly
means either deleting the palm alley or re-cutting **all ~18,000 studs** of river — that is Job #076
territory, not something to slip into an asset job.

### Lessons from #077 that are now shared code — reuse them, don't re-derive

The root cause of every #077 failure was **one sample validating a large footprint** (models 43–218 studs
across, on a meandering river). The fixes now live in shared helpers: `FoliageDefs.groundClearFraction`,
`ExcursionServer.bankForSlice`, sliced per-Z `carve()`, stump-aware `groundAt`, `terrainReadyAt()`,
`settleTerrain()`. Also: **terrain writes are not raycast-readable in the same script** — settle 2 frames
first.

---

## 6. Checklist to close #079

- [x] Implementation — all four held items real, verified in Play
- [x] Turret audio wired and verified live
- [ ] `final-summary.md`
- [ ] `changelog.md`
- [ ] Import the 3 GLBs → measured pass
- [ ] **Save the place** (`ServerStorage` is not Rojo-synced)
- [ ] Commit (yours)
