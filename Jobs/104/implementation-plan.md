# Job #104 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) + one mirrored shared file (see §6)
**Status**: agreed 2026-08-23 (all four wizard answers = the recommended option)

## The requirement, in the user's words

> "We currently can buy pistol but not ammo. So we need add ammo to pistol and shotgun. Also we need to
> increase shotgun size (it is small as asset) like twice, also shotgun must be 2x stronger."

Three separate deliverables. All three are in the GAME place.

## What is true today (read, not assumed)

- The village/dock trading post (`ShopDefs` + `SalvageServer` + `DockShopClient`) sells six things:
  bandage 50 · fuel 120 · **"Ammo Box" 90** · repair 150 · pistol 400 · shotgun 750.
- 🔴 **That "Ammo Box" is the BOAT TURRET's ammo**, not handheld ammo — it adds `+1` to the boat's `Ammo`
  cargo attribute (`SalvageServer.applyItem`, the `fuel`/`ammo`/`repair` branch). Its name is why the
  report says ammo can't be bought: the one row called "Ammo" does nothing for the pistol in your hand.
- Handheld ammo is **per-player, per-gun** on a Player attribute (`AmmoPistol` / `AmmoShotgun`,
  `ItemDefs.ammoAttr`) and today has exactly two sources:
  `ammoOnLoot` (24 / 8, granted by `InventoryService.grant`) and `ammoPerCrate` (18 / 6, granted by an
  `Ammo` loot crate at a camp — `ExcursionServer` ~line 832).
- So the only way to buy pistol ammo right now is to **buy a second 400-salvage pistol** — `grant()`
  tops up ammo when the gun is already owned. That is the accidental workaround, and it is terrible value.
- Held shotgun size: `WeaponAssets.ART.Shotgun.scale = 0.421` against a MeshPart **measured live in
  Studio at 5.70 × 1.33 × 0.34** → held length **2.40 studs**, under half a character's height. Matches
  the report.
- Shotgun damage: `ItemDefs.Items.Shotgun.damage = 12` **per pellet**, `pellets = 6` → 72 at point blank.
  `WeaponServer` applies it per ray; no other multiplier touches it (the `SkillGun` skill changes only
  `fireInterval`).

## Decisions (wizard, all recommended options)

| # | Decision |
|---|---|
| 1 | **Two shop rows, one per gun** — "Pistol Ammo" and "Shotgun Ammo". Also rename the existing row to **"Turret Ammo"**, because that row's name is half the reported bug. |
| 2 | **One purchase = one crate's worth**: pistol **+18 rounds / 60**, shotgun **+6 shells / 90**. |
| 3 | **Must own the gun** — server refuses; the row shows a muted `NEED PISTOL` / `NEED SHOTGUN`. |
| 4 | Independent reviewer agent runs (GROUND-RULES §8). |

**The amount is not hand-copied.** `18` and `6` already exist as `ItemDefs.ammoPerCrate`; the shop reads
them, so a future balance pass tunes one number and the shop, the loot crate and the blurb all move
together. This is the same drift `ItemDefs.TURRET_ROUNDS_PER_CRATE` was created to stop.

## Changes

### 1. `sync/ReplicatedStorage/Inventory/ItemDefs.luau` — shotgun 2× stronger
`Shotgun.damage` **12 → 24** (per pellet ⇒ 144 for a full 6-pellet hit).

Balance consequence, stated explicitly: a full point-blank hit already killed every land threat
(Bandit/Boar/Wolf are 50–55 HP). What actually changes is **margin** — the shot still kills when only
3 of 6 pellets connect (72) instead of needing 5 — and the **RiverHippo (120 HP)** drops from two shells
to one. Priced against that: 6 shells cost 90, i.e. 15 salvage a shell vs the pistol's 3.3 a round.

### 2. `sync/ServerStorage/Inventory/WeaponAssets.luau` — shotgun 2× bigger
- `scale` **0.421 → 0.842** (2.40 → **4.80** studs held length; source MeshPart measured, not trusted
  from the comment).
- `gripOffset` **(-0.6, -0.15, 0) → (-1.2, -0.30, 0)** — ⚠️ **this must scale with the model.** The grip
  is an absolute stud offset applied *after* `Size *= scale` (`InventoryService.updateHeldVisual`), so
  doubling the mesh without doubling the grip slides the hand from ¼ along the gun to ⅛ along it and the
  stock ends up through the character's chest.
- The gun's `Sound`s are children of the part and carry no `Attachment`, so nothing else scales.

### 3. `sync/ReplicatedStorage/Economy/ShopDefs.luau` — two new rows
- `ShopItem` gains two optional fields: `ammoFor: string?` (the `ItemDefs` id this row feeds) and
  `amount: number?` (resolved from `ItemDefs.ammoPerCrate`, so it is derived, never typed twice).
- New: `pistolAmmo` (60) and `shotgunAmmo` (90), blurbs built with the resolved amount
  (`"+18 rounds for the pistol"`).
- `ammo` row renamed **"Ammo Box" → "Turret Ammo"**, blurb `"+1 ammo crate for the boat's gun"`. Id stays
  `ammo` (it crosses the remote; renaming the id buys nothing).
- `Order` becomes `bandage, fuel, ammo, repair, pistol, pistolAmmo, shotgun, shotgunAmmo` — each gun's
  ammo directly under it.

### 4. `sync/ServerScriptService/Economy/SalvageServer.server.luau` — the buy
`applyItem` gains an `ammoFor` branch, **before** the resource branch:
1. `InventoryService.owns(plr, def.ammoFor)` → else `return false, "nogun"` (no salvage deducted; the
   existing flow only deducts after `applyItem` succeeds).
2. `InventoryService.addAmmo(plr, def.ammoFor, def.amount)`.

### 5. `sync/ServerStorage/Inventory/InventoryService.luau` — one helper
`InventoryService.owns(player, itemId): boolean` — scans `Slot1..slotsFor(player)`. `grant()` already
does this scan inline twice; the helper is the same loop named once, and the server must do the
ownership check itself (the client's gate is only cosmetic).

### 6. `sync/ReplicatedStorage/UI/Theme.luau` (+ the lobby mirror) — the two icons
Two new `Theme.icon` keys with the **user's own verified uploads**:

| Key | Asset | Id | Verified |
|---|---|---|---|
| `pistolAmmo` | `clip` (revolver cylinder) | `98656594796808` | `GetProductInfo` → name `clip`, AssetTypeId **1** = Image, creator `johnygorsky10` |
| `shotgunAmmo` | `bullets` (two shotgun shells) | `107222226747372` | `GetProductInfo` → name `bullets`, AssetTypeId **1** = Image, creator `johnygorsky10` |

No `iconPending`/`iconFallback` rows — the art is landed, which is that mechanism's end state.

⚠️ **`sync/ReplicatedStorage/UI/Theme.luau` and `lobby/sync/ReplicatedStorage/UI/Theme.luau` are
byte-identical by contract** (verified with `diff` before touching either). The lobby has no trading post
and no loadout, but the file must stay identical, so the same two keys are added to both copies —
exactly as `Theme.itemIcon` already carries game-only keys. **This is the only file touched outside
`sync/`, and only to preserve that contract.**

### 7. `sync/StarterPlayer/StarterPlayerScripts/UI/DockShopClient.local.luau` — icons + the gate
- `ITEM_ICON`: `pistolAmmo = "pistolAmmo"`, `shotgunAmmo = "shotgunAmmo"`.
- `refreshAll` learns a second reason a row can't be tapped. Precedence: **no gun** beats **too poor**
  (there is no point telling someone they need 60 salvage for shells they can't use):
  `NEED PISTOL` / `NEED SHOTGUN` → muted · else `NEED 60` → muted · else `BUY 60`.
- Rows stay **muted, never disabled** — `setEnabled(false)` kills `Activated`, and the file's own comment
  records why that is wrong: no `flashFail`, no `fail` cue, reads as a broken button.
- The panel must re-render when a gun is looted/dropped while it is open, so it also listens to
  `Slot1..MAX_SLOTS` attribute changes (the existing listener only watches `Salvage`).
- Mobile: the list is a `ScrollingFrame` with `AutomaticCanvasSize.Y`, so 8 rows scroll rather than
  overflow. To be **verified in the emulator, not assumed** — 8 × `Theme.rowHeight` in a 0.74-height
  panel is the case that would break, and I will ask before switching Studio to Device mode.

### 8. Bookkeeping
- `roblox.workspace/Assets/registry/images.md` — log both icons (name/id/project/where used).
- `ASSETS.md` — record the two icons as delivered.
- **Finding to log**: registry `images.md` still lists the 16 Job #075 HUD icons as "⏳ PENDING" with
  empty ids, while `Theme.luau` has had all 16 real ids since 2026-08-16. The registry is stale, which
  defeats "grep the registry before sourcing" — it is why this job's first instinct was to go source
  icons we may already have had.

## Not doing (and why)

- **No change to `ammoOnLoot` / camp `Ammo` crates.** Buying is being *added* as a source, not replacing
  looting. Untouched.
- **No shotgun price change.** The user asked for 2× damage, not a re-priced gun; the shell price already
  carries the buff. Flagged, not decided unilaterally.
- **No `lobby/` gameplay changes.** The lobby's own `InventoryService` copy (which still draws the old
  greybox `2.4`-stud gun barrel) is out of scope — different place, GROUND-RULES §1.

## Verification (GROUND-RULES §7 — in Play, and it must be able to fail)

Each check names what failure looks like.

| # | Check | Fails if |
|---|---|---|
| 1 | In Play, buy Pistol Ammo with the pistol owned | `AmmoPistol` does **not** rise by exactly 18, or salvage does not fall by exactly 60 |
| 2 | Buy Shotgun Ammo **without** a shotgun | Salvage is deducted, or `AmmoShotgun` rises, or the row silently does nothing (no `flashFail`) |
| 3 | Fire the pistol dry, then buy ammo, then fire | The dry click never plays, or the gun stays dead after the purchase |
| 4 | Held shotgun, screenshot from the player camera — **before/after from the same camera** | The gun is not visibly ~2× longer, or the hand is no longer on the grip, or it clips through the body/camera |
| 5 | Shoot a live enemy with the shotgun, read the server damage line | Reported damage is not ~2× the pre-change number for the same pellet count |
| 6 | Both new rows render with the right icon and readable text | An icon is blank/wrong, or a row's label is clipped |

Before/after screenshots kept for #4 (the "every visual change gets a before/after" rule).

## Human actions needed

- **Studio open on the GAME place** — `Last River COOP Game (placeId: 138141472932347)` — already
  connected and used for the measurements above.
- ✅ Icons: already supplied and verified. Nothing else to source.
- Possible ask later: permission to switch Studio to the Device emulator for the mobile row check (§7).
