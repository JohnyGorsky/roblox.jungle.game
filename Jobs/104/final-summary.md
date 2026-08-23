# Job #104 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`) + `lobby/sync/UI/Theme.luau` (mirror contract only)
**Completed**: 2026-08-23

## What was asked

> "We currently can buy pistol but not ammo. So we need add ammo to pistol and shotgun. Also we need to
> increase shotgun size (it is small as asset) like twice, also shotgun must be 2x stronger."

All three delivered, plus three follow-on decisions the user approved via the wizard mid-job.

## The report was exactly right, and the cause was a NAME

The trading post already had a row called **"Ammo Box"** — but that row adds `+1` to the *boat's* `Ammo`
cargo, which feeds the **mounted turret**. It does nothing for the pistol in your hand. Handheld ammo is a
separate per-player pool (`AmmoPistol` / `AmmoShotgun`) whose only sources were loot. So the one row named
"Ammo" was the wrong ammo, and the only way to buy pistol rounds was to **buy a second 400-salvage
pistol**, because `grant()` tops up ammo on a gun you already own.

An independent reviewer (GROUND-RULES §8, run with only the user's words) then found the deeper reason the
shotgun half of the request was thin: **the shotgun never spawned as loot at all** (see §4).

## Changes

### 1. Buyable handheld ammo
- `ReplicatedStorage/Economy/ShopDefs.luau` — two new rows, `pistolAmmo` (60 salvage) and `shotgunAmmo`
  (90). Each carries `ammoFor` (the gun it feeds) and `amount`. **The amount is read from
  `ItemDefs.ammoPerCrate`** (18 / 6) rather than typed here, so the loot crate, the shop and the blurb can
  never disagree. The old row was renamed **"Ammo Box" → "Turret Ammo"** (id unchanged — it crosses a
  remote); that rename is arguably the highest-value line in the job.
- `ServerScriptService/Economy/SalvageServer.server.luau` — an `ammoFor` branch keyed off the catalog, not
  a hardcoded id list. Requires owning the gun (`"nogun"`), and returns before any salvage is deducted.
  Also **moved the remote creation above the requires**: `ExcursionServer` blocks on
  `WaitForChild("OpenShop")` at load, and `ShopDefs` now has a dependency, so a stall here would have
  taken out camps/docks/loot entirely. Failure is now local to the shop.
- `ServerStorage/Inventory/InventoryService.luau` — new `InventoryService.owns()`. Scans `MAX_SLOTS`, not
  `slotsFor(player)`: the latter reads the async `Owns_extraSlots` pass attribute, so a pass owner with the
  gun in slot 5–6 would have been told they own no gun until it landed.
- `StarterPlayerScripts/UI/DockShopClient.local.luau` — the two rows, their icons, and a muted
  `NEED PISTOL` / `NEED SHOTGUN` state (muted, never disabled — disabled kills `Activated`, and then a tap
  gets no explanation). Re-renders on `Slot1..6` changes, not just on `Salvage`.

### 2. Shotgun 2× bigger
`ServerStorage/Inventory/WeaponAssets.luau` — `scale` **0.421 → 0.842**; source MeshPart **re-measured live
in Studio** at 5.70 × 1.33 × 0.34, so held length goes **2.40 → 4.80 studs**. `gripOffset` doubled to
`(-1.2, -0.30, 0)`: it is an absolute stud offset applied *after* `Size *= scale`, so leaving it alone
would have slid the hand from ¼ along the gun to ⅛ and put the stock through the character's chest. The
greybox fallback in `InventoryService` was moved 2.4 → 4.8 to match, or the change would look like a no-op
in any place without the (non-synced) `AssetLibrary`.

### 3. Shotgun 2× stronger
`ReplicatedStorage/Inventory/ItemDefs.luau` — `Shotgun.damage` **12 → 24 per pellet** (6 pellets = 144).

### 4. Three approved follow-ons
- 🔴 **The shotgun now actually drops.** `ExcursionServer:1816` read
  `if index % 2 == 0 then "Shotgun" else "Pistol"`, but `index` is the **dock** ordinal and only **odd**
  docks are landings (`RiverData:319`) — so the Shotgun arm was dead code. Every weapon crate in the game
  was a Pistol, and since the ammo crate reuses `weaponId`, **all** handheld ammo loot was pistol ammo.
  Now keyed on `tier` (the landing ordinal), verified against the real river data: 6 landings, previously
  0 shotgun crates, now 3 pistol / 3 shotgun alternating.
- **Turret kept ahead of the handheld.** `GunServer.GUN_DAMAGE` **60 → 75**. At 24/pellet the shotgun does
  205.7 dps against the turret's 200 — which would have made "nobody mans the gun" optimal and quietly
  deleted a crew role that `GAME.md:147` calls *"the boat's real firepower"*. 75 restores the gap (250 dps)
  without clawing back what the user asked for.
- **Ammo rows moved above the guns.** A phone shows ~3 of 8 rows; paired under their guns the ammo rows sat
  at positions 6 and 8, so the player who reported "can't buy ammo" would have had to scroll past the fix.

### 5. Two defects found *by* this work and fixed
- 🔴 **A refused purchase looked like a successful one.** `DockShopClient` tested
  `res.salvage ~= nil`, but the server returns the balance on failure too — so `poor`, `invfull`,
  `cargofull` and the new `nogun` all produced the green `Components.burst` and the purchase-success chime
  with nothing granted ("the ammo I paid for vanished"). Now tests `res.ok == true`. The new ownership gate
  is the path that would have hit this constantly.
- 🔴 **The muzzle flash fired from the character's fist.** `WeaponClient` placed it at
  `held.CFrame * CFrame.new(0, 0, -Size.Z/2)`, with a comment asserting the gun's long axis is `-Z` — true
  only of the retired greybox box. Both real guns are barrel-along-`+X`, so `Size.Z` was the gun's 0.29-stud
  *thickness*. Doubling the shotgun doubled the error to 2.4 studs and made it obvious. It now picks the
  face centre furthest along the shot direction, which is correct for the `+X` meshes, for the `-Z` greybox,
  and for any weapon added later.

### 6. Icons (user-supplied, verified)
`Theme.icon` gains `pistolAmmo` = `clip` **98656594796808** and `shotgunAmmo` = `bullets`
**107222226747372** — the user's own uploads, delivered mid-job. Both verified in Studio with
`GetProductInfo` (name match, AssetTypeId **1** = Image, creator `johnygorsky10`). Deliberately **not** the
existing `ammoBox` crate: that is the turret's glyph, and one icon across three rows is the confusion this
job exists to remove. Logged in `ASSETS.md` §5.2b and the shared registry.

⚠️ `sync/.../UI/Theme.luau` and `lobby/sync/.../UI/Theme.luau` are byte-identical by contract; `diff` was
clean before and after. That mirror is the **only** file touched outside `sync/`.

## Verification — in Play, and every check able to fail

| # | Check | Result |
|---|---|---|
| 1 | Buy sequence through the real `DockShop` remote | 2000 → refusal **no change** → −750 shotgun (ammo 8) → −90 shells (**8→14**) → −400 pistol (ammo 24) → −60 rounds (**24→42**). Every figure exact. |
| 2 | Ammo for a gun you don't own | `"nogun"`, **no salvage deducted**, no ammo granted — three separate clicks |
| 3 | Refusal must not *look* like a purchase | Watched for the `Burst` frame the success path parents into the row: **refusal 0, real purchase 1**. The positive control is what makes the 0 meaningful. |
| 4 | Real mouse clicks on the real buttons | 3 clicks on `Btn_60` / `Btn_400` → 2000 → 1540 with `AmmoPistol` 42 |
| 5 | Held shotgun size | measured **4.80 × 1.12 × 0.29** on the live `HeldItem`, exactly 2× the old 2.40; hand-to-centre 1.24 studs = the grip still ¼ along the gun |
| 6 | Before/after from the same camera | first-person screenshots: old = a stub barely longer than the hand; new = a full-length shotgun, hand on the grip, **no clipping into the body or camera** |
| 7 | **Damage, live fire** | One trigger pull: croc **1000→904 (96)** and a second croc behind it **1000→952 (48)** = 6 pellets × **24**. Server log shows six HIT lines, every drop exactly 24. At the old 12/pellet these read 48 and 24. |
| 8 | Panel renders | 8 rows, correct icons, both gates reading `NEED PISTOL` / `NEED SHOTGUN`; ammo rows now on screen without scrolling |
| 9 | 8-row overflow | **Caught in Play, not reasoned about**: the list had `ClipsDescendants = false`, so the 8th row drew *outside* the panel over the world. Now clips + scrolls, with a 12 px pad so the badge overhang (1.34 × row height) still shows whole. |
| 10 | Camp loot mapping | Ran against real `RiverData`: all 6 landings previously Pistol; now 3 Pistol / 3 Shotgun |
| 11 | Analyzer | `tools/luau-analyze.sh` clean on every touched file — and **proved able to fail** (a planted type error returned exit 1) |

### ⚠️ NOT verified in gameplay
**The turret's 60 → 75.** Three attempts failed for an environmental reason, not a code one: at the mooring
the turret's line is blocked by spawn-base foliage — 30+ rounds logged
`[Gun] hit ...Fern_OuterLeaves — not an enemy` — and no enemy ever presented a clear line. A client-side
line-of-sight check *disagreed* with the server because with `StreamingEnabled` the client had not loaded
those ferns (now finding 0023).

The change is one constant on the only line that reads it (`GunServer:253`), synced and analyzer-clean, but
it has **not** been confirmed by a live hit. **The check to run once the boat is under way:** set a chasing
croc's `HP` to 1000, fire one turret round, expect **90** (75 × 1.2 Armored Boat) — the old value reads 72.

## Findings logged (not fixed here)

`0015` stale icon registry · `0016` shotgun loot parity *(fixed in this job)* · `0017` rejoin re-seeds the
loadout and destroys bought guns/ammo · `0018` re-buying a gun still tops up ammo at 6× the price ·
`0019` village HP ramp twice as steep as documented · `0020` Armored Boat pass advertises +20% weapon
damage but only the turret gets it · `0021` `WeaponClient` hardcodes the ammo attribute names ·
`0022` dropping a gun leaves its ammo counter · `0023` foliage leaf parts block gunfire.

## Balance note (flagged, not decided)

144 per shell doesn't change *what* the shotgun kills at landing 1 — 72 already killed every 50–55 HP land
threat — it changes the **margin** (3 of 6 pellets now suffice instead of 5) and it collapses the
per-village HP ramp for shotgun users: a landing-6 Bandit at ~143 HP now dies to one shell **by 1 HP**.
The RiverHippo (120) drops from two shells to one. Shells are priced against that at 15 salvage each vs
the pistol's 3.3. If it plays too strong, the lever is `pellets`/`spread` (close-range only) rather than
per-pellet damage.
