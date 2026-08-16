# Asset gaps — everything Last River still needs (snapshot 2026-08-16)

Read from `ASSETS.md`, the shared registry, and the live code — **not** from memory. `ASSETS.md` stays
the bible; this is a dated summary of what is still OPEN, ordered by what a player notices first.

> ✅ **Recently closed:** all 6 creatures (#078) · all 4 held weapons + the whole weapon audio set (#079)
> · dock camps / docks / trading posts (#077) · camp night practicals + the river log jam (#079) · boat
> wake VFX + boat damage audio (#081) · **all 5 HUD sounds (#081, 2026-08-16)** · **all 6 boat upgrade
> models — verified, they were already done in the lobby** · waterfalls / zone dressing / intro art /
> lobby lanterns (**user: not needed, already done**). None of those appear below.

---

## 1. ✅ HUD icons — CLOSED 2026-08-16

All 16 landed in one Flaticon batch and are wired in `Theme.icon` (both trees, byte-identical). Verified
in Play: `iconPending` empty, `iconFallback` empty, boot warning gone, and **all 16 resolve**
(`ImageLabel.IsLoaded` after `PreloadAsync`).

> ⚠️ `axe` briefly failed to load on first check and passed minutes later — it was in **image
> moderation**, not broken. `GetProductInfo` confirmed the asset existed and was a valid Image the whole
> time. If a fresh upload fails to render, check moderation before touching code.

**The `machete` key is gone** — renamed to `axe` (Job #079 made the starting melee an axe), and
`Theme.itemIcon.Axe` points at it. No `machete` reference survives anywhere in either tree.

## 2. ✅ HUD sounds — CLOSED 2026-08-16

All five landed in one upload batch and are wired in `Theme.sound` (both trees, byte-identical):
`lowFuel` 76291949644634 · `lowHull` 77018431817918 · `downed` 139285102940691 ·
`revived` 74705196258655 · `runLost` 94363214324807.

`Theme.soundPending` is now empty and the boot warning is gone — verified in Play. All five resolve and
are moderation-approved (`ContentProvider:PreloadAsync` + `IsLoaded`, 0 failures).

## 3. ✅ Boat audio — CLOSED 2026-08-16

Wired in `BoatSound` (Job #081): `metal_hit_1_sec` 108683025674193 on a hit ≥18% MaxHP ·
`boat_on_fire` 76815433524413 looping under 30% hull (17.2 s clip) · `boat_destroyed` 102492807352506
at zero.

> ⚠️ **Two dead duplicates to delete from the account.** `boat_destroyed 89814954215320` and
> `boat_on_fire 85716055048481` were uploaded earlier the same day and briefly wired; the batch above
> supersedes them and nothing references them now.
>
> The remaining local `.mp3`s (`boat_engine_loop_5_sek`, `diesel_motor_start`, `motor_loop`) are
> **alternates** for the engine loop that is already wired. Leave them; do not upload duplicates.

## 4. ✅ Boat upgrade models — CLOSED (already done, verified 2026-08-16)

Every purchasable module resolves real mesh art through `BoatParts.skin()`; the greybox in
`BoatModules` is only the fallback for when art is missing. Verified live via `BoatParts.hasArt`:

`motor2`→Motor · `hullPlate`→HullPlate · `fuelTank`→FuelTank · `searchlightMast`→SearchlightMast ·
`searchlightHead`→SearchLightHead · `trailer`→CargoRacks · `gunBarrel`→GunBarrel — **all 7 hasArt=YES.**

> ⚠️ `ASSETS.md` §2 still describes these as greybox. **That is stale** — it predates the lobby work.

## 5. 🟡 World set-pieces — ramp GAMEPLAY done, only its ART left

| Item | State |
|---|---|
| **River ramps — logic** | ✅ **DONE (#082, 2026-08-16).** Job 019's proven launch promoted onto the real `ramp` hooks; verified in Play at **+22.2 studs** off a 32° ramp. Non-colliding triggers. |
| **River ramps — art** | 🟡 **THE ONLY OPEN ASSET besides the icons.** Currently a grey `WedgePart` — correctly angled and readable, but blocky. A Meshy `RiverRamp` drops in by name with no code change. |
| Waterfalls · zone dressing · plane-crash intro · lobby lanterns | ✅ user 2026-08-16: not needed / already done |

> ⚠️ Do not confuse the river ramp with `BoatParts.ramp` → `RampBow`, the BOAT's bow-ramp module, which
> already has art (`hasArt = YES`).

## 6. 🟢 Enemies — only the Anaconda

All six current creatures are done. The Anaconda exists **only as concept art**
(`assets/Enemies/Anaconda.png`).

⚠️ It is a **gameplay change, not an art swap** — it needs stats, a category (sea or land), spawn rules
and a balance pass before a model is worth generating.

## 7. Not assets, but tracked in ASSETS.md

- **Weekly leaderboard** is a `"coming soon"` placeholder. It needs a weekly `OrderedDataStore` +
  rollover — code, not art.
- **15 of 16 game HUD scripts are still hand-rolled**; only `RobuxShop` consumes the `Theme`/`Components`
  design system that was ported in #074.

---

## Suggested order

1. **River ramp ART** (§5) — the only remaining asset in the game.
   edge, and the only remaining ART gap in the game.
2. **Anaconda** (§6) — only if its gameplay is ever decided (currently skipped).
