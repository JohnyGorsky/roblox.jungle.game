# Job #079 — final summary

**Project**: `roblox.jungle` · **Started** 2026-08-15 · **Completed** 2026-08-16

Began as "reuse Defender's axe". Grew to **all four held items**, then **all weapon audio**, then the
three Meshy props that closed the last of the camp/river greybox.

---

## What shipped

### Part 1 — held items (2026-08-15)

Nothing in your hands is a coloured box any more.

| Item | Model | Sound | Animation |
|---|---|---|---|
| **Axe** (starting weapon) | rebuilt from Defender's ids — mesh `145815658` / texture `186913315` / decal `4657174543` | `AxeSwing` `210946558` · `AxeChop` `8936215056` · `Equip` `2304904662` | `slash1` `567480700` / `slash2` `567479941`, alternating |
| **Pistol** | Meshy → `AssetLibrary.Weapons.Pistol`, scale `0.316`, yaw `+90°` | `fire` `138178318678571` · `empty` `75733077651437` | — |
| **Shotgun** | Meshy → `AssetLibrary.Weapons.Shotgun`, scale `0.421`, yaw `+90°` | `fire` `129597576449946` · `pump` `113837896417526` · `empty` `75733077651437` | — |
| **Torch** | **built in code** — stick + `Fire` + embers + `PointLight` | crackle `113774133604878` | — |
| **Boat turret** | existing `GunBarrel` | `fire` `138178318678571` · `empty` `135106168511714` · `reload` `134765294816468` | — |

The turret was the last gap: it had **no audio at all**, and `gun_reload` had nowhere to play because
handheld guns have no magazine — the turret is the only weapon that reloads, swallowing an `Ammo` crate
from boat cargo. Verified in Play: 12 shots → `fire=1 reload=1 empty=0`, then drained → `empty` ×3.

**Balance untouched.** Axe stays at damage 15 (not Defender's 20), `meleeRange` 9, `swingInterval` 0.6 —
Jobs 015 and 058 tuned the on-foot camp raid against those numbers.

### Part 2 — three Meshy props (2026-08-16)

| Model | Where | Result |
|---|---|---|
| **`Lantern`** | `CampAmbience` perimeter practicals, 2 per camp | scale **0.63** → 2.39 studs, stands on the sandbag wall, light at the glass |
| **`LogJam`** | `RiverBootstrap.OBSTACLES`, 4th type | floats, `submerge 0.45`, slow **0.72** / damage **16** |
| **`GoldChest`** | `buildTradingPost`, out front of the vendor | scale **0.65** → 6.14×4.78×7.41, dressing only |

Also removed: the **`SwingFx` cream Neon slab** in `MeleeClient` — a Job #075 placeholder that read as
"a white object flying" when you swung. The real axe animation replaces it.

---

## The three bugs worth remembering

### 1. `Model:ScaleTo` is ABSOLUTE, and the 3D Importer bakes a scale in

`ExcursionServer.prop` called `clone:ScaleTo(scale)`. `GoldChest` arrives from the importer at
`GetScale() = 6.0`, so `ScaleTo(0.65)` measured against the **raw mesh** and produced a **1.02-stud**
chest instead of a 6.14-stud one.

Fixed to `clone:ScaleTo(clone:GetScale() * scale)`, which is what `CampDefs.SCALE`'s own comment always
claimed and what `CampAmbience` and `WeaponAssets` already did. **Safe:** the only existing entries are
`Tent` and `RangerTower`, both at `GetScale() = 1.0` where absolute and relative are identical — verified
unchanged after the fix (Tent 18.06×5.65×14.07, RangerTower 43.35 tall).

> 10 of the 39 library models carry a baked scale: `GoldChest` 6.0 · `LogJam` 4.0 · `Boar` 3.0 ·
> `Lantern` 2.0 · `RobuxShop` 1.564 · `SkillTrainer` 1.29 · `BoatUpgrades` 1.084 · `Plane` 0.5 ·
> `RunWay` 0.458 · `Pilot` 0.05.

### 2. A constant that predicts where another system put something

The lantern's mount height started as `groundY + 5.30` (SandbagWall's 5.60 height less `prop`'s 0.30
sink). **Every lantern floated exactly 1.0 stud.** The arithmetic was right; the inputs disagreed —
`prop` seats each sandbag on its own `groundAt(x, z)`, while `params.groundY` is the ground under the
**campfire**, and carved camp floors are not flat.

Replaced by `CampAmbience.mountFor`, which finds the actual `SandbagWall` at the slot and measures its
top (falling back to a terrain raycast where a camp has no sandbags). Verified 4/4 seated, worst gap
**0.000**. Same lesson as `FoliageDefs`' footprint validation: **measure, don't predict.**

### 3. The chest under the stilt house

`counterPos` is only `approach * 10`, but `BahayKubo7` is **40×50 studs** — so the counter (an invisible
prompt anchor, which doesn't care) is *inside* the building, and the chest landed under its deck.
`buildTradingPost` now measures the post's bounding box and steps outside it.

---

## 🔴 Verifying anything in a streamed world

Three screenshots during this job showed "no lantern" and were **all invalid**. Moving only the client
camera to a camp leaves the client with **0 BaseParts** for that landing site — `StreamingEnabled`
follows the **character**, which was 2,000 studs away. The camp still appeared to render, which is what
made it convincing, and `WorldToViewportPoint` cheerfully reported "on screen, clear line of sight".

> **Move the character, wait, then confirm the client actually holds the parts** (940 for a landing site)
> before trusting any in-game screenshot.

Also: teleporting into a camp gets you downed by guards in seconds and the "YOU ARE DOWN" panel covers
the middle of the screen. Stand ~100 studs off — outside the 55-stud leash, inside streaming range.

---

## Files

**New:** `sync/ServerStorage/Inventory/WeaponAssets.luau`

**Modified:** `InventoryService.luau` · `MeleeServer` · `MeleeClient` · `WeaponServer` · `GunServer` ·
`ItemDefs` · `Theme.luau` (both trees, `Sword`→`Axe`) · `CampDefs` · `CampAmbience` · `ExcursionServer` ·
`RiverBootstrap`

**Docs:** `ASSETS.md` (§3.2 weapon audio, §3.6 new) · `Planned/asset-gaps.md` ·
`roblox.workspace/Assets/registry/{models,audio}.md`

## Verification

- [x] `bash tools/luau-analyze.sh` → exit 0
- [x] Both `Theme.luau` copies byte-identical
- [x] Weapon audio verified in Play (turret fire/reload/empty counted off the console)
- [x] Lantern: 4/4 seated on the sandbag line, worst gap 0.000, lit at night, screenshotted
- [x] LogJam: spawns, trigger invisible + non-colliding, mesh stretched exactly to trigger, floats 3.3
      studs proud of the waterline, screenshotted in the river
- [x] GoldChest: 6.14×4.78×7.41, clear of the trading post footprint, screenshotted
- [x] Tent + RangerTower unchanged by the `ScaleTo` fix
- [x] Console clean — no errors, no missing-asset warnings
- [x] Edit place clean (no test scaffolding), camera restored to `Custom`

## Credits

**150 Meshy credits** (1600 → 1450): Pistol + Shotgun 60, GoldChest + Lantern + LogJam 90. The Axe cost
nothing — cross-game reuse. Wolf, Bandit and Boar in Job #078 likewise.

## Known / deferred

- **`LogJam` art** came back bleached and tidy rather than the mossy waterlogged tangle prompted for.
  **Kept by your decision** 2026-08-16; it is legible on the water, which is what an obstacle needs.
- Adding a 4th obstacle type shifts the mix from 3 to 4 (each ~25%); average damage per hit moves
  13.67 → 14.25. Flagged, not a balance job.
- **Gold economy untouched.** The chest grants nothing. Gold's only source is still `trySpawnNugget`
  (25%/camp, 1 Gold, capped 3/run). Giving the chest a prompt is an economy change needing a value, a
  rate and a cap — see its comment in `CampDefs`.
- **Lobby lanterns still open** — the `Lantern` wired here is in the GAME place; the lobby is a separate
  place file and needs its own import.
- 16 HUD icons + 5 HUD sounds remain (`Planned/asset-gaps.md`). ⚠️ The empty icon ids are the tracking
  mechanism — `Theme.iconFallback` already substitutes. Do not "fix" them by reuse.
- Pre-existing, unrelated: `[BoatPaint] library not prepared — run BoatParts.preparePaintLibrary() in
  Studio (Edit) and save the place`.

> ⚠️ **Save the place.** Every weapon and prop model lives in `ServerStorage`, which is not Rojo-synced.
