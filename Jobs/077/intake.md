# Job #077: Dock camps + docks on real assets (tents, crates, barrels, sandbags)

**Project**: `roblox.jungle`
**Created**: 2026-08-05 20:46:29
**Status**: Requirements gathering — audit below is done; plan not written yet.

> **Why this job exists:** Job #076 was deliberately scoped to terrain + foliage + river obstacles, and I
> wrote that camp structures would get "their own job" — then didn't create it. This is that job, created
> when the user asked for it directly. #076 still takes the camp **trees** (it owns the foliage picker);
> #077 takes everything built.

## Requirements / goal

Replace the greybox structures at the dock excursion camps and the river docks with the real AssetLibrary models. Greybox to retire: ExcursionServer camp Huts (2 blocks per camp) -> Tent; LootCrate blocks (resource crates + weapon/ammo kind-crates) -> CrateWood / AmmoBox / Barrel; the hand-assembled TradingPost stall (platform + counter + 4 posts + fabric awning + floating billboard) -> a real market stall dressed from Tent + CrateWood + BarrelsSet + a wooden sign instead of a BillboardGui; GoldNugget Neon cube; CarriedCrate (the box welded over your head while hauling) -> CrateWood; and DockServer's plank Deck -> the real Dock model. Every ProximityPrompt, tag and attribute (Resource, Kind, Id, TiePrompt, LootPrompt) must carry over untouched, and the loot/tie/untie flows must not change behaviour. Also worth using: SandbagWall / SandbagBarrier to fortify camps, RangerTower as a camp landmark. Companion to Job 076 which does the terrain + foliage bands and the camp TREES. Asset audit first - list anything genuinely missing (likely: a market-stall/awning piece and a gold-nugget prop).

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written


---

# The audit

## Greybox to retire — measured from the code

| Greybox | Built at | Per camp | Real asset |
|---|---|---|---|
| `Hut` × 2 (10×8×10 + 8×6×8 blocks) | `ExcursionServer:227-228` | 2 | **`Tent`** (43×13×34, 1 mesh) |
| `LootCrate` (4×4×4, tinted per resource) | `ExcursionServer:230` | 1–3 | **`CrateWood`** (66 parts ⚠️) or **`Barrel`** (6) / **`BarrelsSet`** (62 ⚠️) |
| `LootCrate` kind-crate (Metal, weapon/ammo) | `ExcursionServer:251` | varies | **`AmmoBox`** (20 parts + 2 mesh) |
| `TradingPost` stall — platform + counter + 4 posts + fabric awning | `ExcursionServer:274-281` | 1 per village | needs assembling from `Tent` + props — **see gaps** |
| `ShopSign` — invisible part + `BillboardGui` "TRADING POST" | `ExcursionServer:283-300` | 1 | a **physical wooden sign** (STYLEGUIDE §5: world signage uses `Theme.font.sign`, not floating UI) |
| `GoldNugget` (2×2×2 **Neon** cube) | `ExcursionServer:86` | 0–3 per run | **nothing suitable** — see gaps |
| `CarriedCrate` (3×3×3 box welded over your head) | `ExcursionServer:185` | per haul | **`CrateWood`**, scaled down |
| Dock `Deck` (14×1×24 plank) | `DockServer:55` | 1 per dock ×11 | **`Dock`** (62 parts, 32×8×13) |

## Available and unused — worth spending

| Asset | Cost | Use |
|---|---|---|
| `Tent` | **1 mesh** | camp huts. Cheapest possible swap. |
| `Barrel` | 6 parts | scattered camp dressing, fuel cache |
| `SandbagWall` | **1 mesh** | fortified camp perimeter — reads as "someone defends this" |
| `SandbagBarrier` | 18 meshes | heavier fortification at the guarded camps |
| `RangerTower` | 128 parts ⚠️ | one per landing as a landmark you can see from the water |
| `Dock` | 62 parts | the real pier |
| `WelcomeSign` / `EntrySign` | 4 parts | physical signage, replacing the floating billboard |

## ⚠️ Part-count watch

`Dock` is 62 parts × up to 11 docks, and `RangerTower` is 128 parts each. Docks stream with the boat so
only 1–2 are ever live — fine. `RangerTower` at every landing needs checking against the Job #076
foliage budget (~5,560 instances live), since both spend from the same frame.

`CrateWood` at **66 parts** is a lot for a loot crate you place three of per camp plus one welded to the
player's head. `Barrel` (6 parts) or `AmmoBox` (22) may be the better default, with `CrateWood` as the
hero crate only.

## Gaps — what may genuinely need sourcing

| # | Missing | Why it isn't covered | Fallback if we don't source it |
|---|---|---|---|
| 1 | **Market stall / awning** | The trading post is currently 8 hand-placed blocks. Nothing in the library is a stall; `Tent` is a sleeping tent, not a counter. | Assemble one from `Tent` + `CrateWood` counter + `BarrelsSet`. Works, won't look designed. |
| 2 | **Gold nugget prop** | It's a Neon cube. There is no small treasure prop. | Tint a scaled `RockA` gold with a subtle glow — acceptable, not great. |
| 3 | **Hard "no" rule check** | `❌ Rejected: Jungle Trees Pack (ClawWOMinerm 119737242130790)` — hidden `Script` + 3,335 parts. Do not re-source. Any new camp asset gets the same `roblox-assets` scan. | — |

## Behaviour that must not change

Every swap is cosmetic. These all carry over untouched:

- `LootPrompt` / `NuggetPrompt` / `TiePrompt` / `MooringPrompt` ProximityPrompts and their `Triggered` wiring
- attributes `Resource`, `Kind`, `Id` on crates — `pickupLoot` reads them
- `CarriedCrate` must stay `CanCollide = false` **and `Massless = true`**; it is welded to the player's
  root and a heavy prop there would change how the character moves while hauling
- the dock's `TieSpot` Attachment position — the tie/untie flow and `StagingServer`/`DockServer` depend on it
- `Dock.PlacePlace` is **not** dock geometry (it's the plane's fly-in marker, 500 studs west) — see the
  `FoliageServer` note about it inflating a bounding box from 681 to 845 studs

## Open questions for the plan

1. Camp **layout** — keep the current hardcoded offsets and just swap models, or re-dress the camp now that
   the pieces are real (tents facing a fire, crates behind sandbags)?
2. `RangerTower` at every landing, some landings, or not at all (128 parts each)?
3. Default loot crate: `Barrel` (6 parts), `AmmoBox` (22), or `CrateWood` (66)?
4. Source a market stall + gold nugget, or use the fallbacks above?
