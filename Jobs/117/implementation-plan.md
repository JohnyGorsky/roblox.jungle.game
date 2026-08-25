# Job #117 — Implementation plan

**Project**: `roblox.jungle` · **Created**: 2026-08-25 · **Status**: awaiting agreement
**Revised** 2026-08-25 after the independent reviewer (GROUND-RULES §8) — see §0b.

---

## 0b. What the reviewer changed (and what I verified myself)

The reviewer was given the requirement and the repo only — never this plan's approach. It found one
defect this plan would have shipped, and four gaps. I re-verified each claim independently rather than
taking it on trust; all confirmed.

### 🔴 The defect: `SkillGun` silently shortens the 2-second lockout

`WeaponServer:128-129` computes `interval = (def.fireInterval or 0.22) * (0.965 ^ gunSkill)`. This plan's
§2 asserted *"`fireInterval = 2.0` **is** `burstDuration` — the burst is its own cooldown"*. **That is
wrong**, and measured:

```
SkillGun  0 -> 2.000 s      SkillGun  5 -> 1.674 s
SkillGun  1 -> 1.930 s      SkillGun 10 -> 1.401 s   (SkillDefs.MAX_LEVEL = 10)
```

At max Gun Discipline the lockout is **1.40 s against a 2.0 s burst** — two bursts overlap for 0.6 s,
~6 extra bullets, ~84 extra damage, on the most expensive weapon in the game. No error, no console line.

It is invisible in exactly the conditions it would be tested in: Studio dev profiles start empty by
decision (`ProfileConfig:24`), and the fix for that is `AdminServer:122-128`'s one-click **"MAX ALL
Skills"** — i.e. the tester is *guaranteed* to be in the broken case and unlikely to notice.

**Fix**: the lockout becomes a **burst-owned latch** (`burstUntil[player]`), not `lastShot` × a
multiplier. The skill multiplier keeps applying to Pistol/Shotgun/turret exactly as today.

⚠️ **This needs your decision, not just a code fix** — see the new question in §11: Gun Discipline's
blurb is *"Shoot faster (guns & turret)"* (`SkillDefs:24`) and players spend Gold on it.

### The four gaps

| Gap | Verified | Consequence for this plan |
|---|---|---|
| **`Components.luau` has already diverged between trees** — game 1106 lines LF, lobby 1309 lines **CRLF**; the lobby has a `chip` button variant the game tree lacks, and `Components.button` resolves an unknown variant to *green primary* silently (`:187`) | ✅ `wc`/`file`/`grep` — confirmed | `Theme.luau:12` claims `diff -r` over the UI folders "must be silent". It isn't. **Author each shop row against the tree it lives in**; do not write one and copy it across. Use only `primary`/`secondary`/`gold`/`danger`. |
| **The kiosk exists only at the crash site.** `StartShopServer` binds to `Workspace.SpawnBase.Stands.RobuxShop`; `StagingServer:220` clears `HubSpawn` and the crew sails away. There is no kiosk on the river | ✅ read `StagingServer:204-225` | "Buying in-run" is really **"buying during staging, before anyone unties"**. Consume-at-join (§1) is not just friendlier, it is the *only* correct point. Verification step 9 reworded. |
| **`Owns_<key>` is set a second time** on `PromptGamePassPurchaseFinished` (`MonetizationServer:108-117`), and `InventoryService.grant:365-372` turns a repeat grant into a silent `+ammoOnLoot` top-up | ✅ read both | A mid-run pass purchase would grant **60 rounds, not 30**, and present as a *rounds* bug rather than a purchase bug. The `M16Granted` guard in §4.5 must be checked **before** granting, not just published after. |
| **Admin must grant both shapes.** `Profiles.recordPurchase` refuses unless `isPersisting` (`Profiles:240-242`), and Marketplace prompts don't complete in Studio | ✅ read | The admin panel gets **two** actions, not one: the immediate in-run M16, *and* the banked lobby charge — otherwise the lobby→run half of the feature ships unexercised. The banked one is a shared grant, so it goes in **both** trees. |

### Confirmed correct, no change

The reviewer independently reached the same conclusions this plan already had on the four load-bearing
design points: the `GrantProduct` single-owner trap, the charge living on the profile (TeleportData
carries **one table for the whole party** — `LobbyServer:316-320` — with no per-player slot), the charge
being a **count not a boolean**, and — importantly — that the write must happen **inside** the `grant`
closure passed to `recordPurchase` so its yield-until-`LastSavedData` covers it. §3.4 already does this;
it is now called out explicitly because a write placed *after* `recordPurchase` returns is unprotected,
and the lobby→game handover is a ProfileStore session steal on **every single run** (`Profiles:116-119`).

### Two findings to log, not fix here

- `RobuxShop` force-closes on `Downed` but **nothing closes it on `RunEnded`** — a purchase is possible
  during the 30 s results screen. The M16 rows are safe (guarded by `M16Granted`), so this is a `findings/`
  entry, not job scope.
- Stale headers: both `AdminServer` copies and the **lobby** `AdminClient` still claim *"IDENTICAL copy in
  both trees"* while having diverged. I am editing three of those files anyway, so I will correct the
  headers — a future wholesale copy in either direction would destroy ~280 lines of game-only tooling.

---

## 0. What was investigated, and what it changed about the plan

Everything below was read before it was written. Four findings moved the design:

| Finding | Where | Consequence |
|---|---|---|
| `rifle_shoot` is **3.888 s of sustained auto-fire**, not a single shot (measured live in Studio: `Sound.TimeLength`) | asset `138005496001979` | Play it **once per burst and `:Stop()` at burst end** — never once per bullet. Per-bullet restarts are the cicada-stacking mistake `GameSoundscape` and `WeaponServer:129` both warn about, and here it would restart a 3.9 s clip 20 times in 2 s. |
| `GrantProduct` is a **single-owner** `BindableFunction` — `PlayerCombat:64` assigns `hook.OnInvoke` outright | `MonetizationServer:39`, `PlayerCombat:58-69` | A second script claiming the hook for the M16 would **silently break paid self-revive** (last writer wins, load order undefined). So the per-run M16 does **not** use the hook at all — see §3. |
| `MonetizationDefs`, `MonetizationServer`, `ProfileConfig`, `Theme` are **byte-identical across both trees** (verified with `diff`); `Profiles.luau` differs only by the Job #098 `hasSeen`/`markSeen` block; `AdminServer`/`AdminClient` have **deliberately diverged**. ⚠️ **`Components.luau` has ALSO diverged** — an earlier draft of this row wrongly listed it as identical; see §0b | file headers + `diff` | Shared files get the *same* edit in both trees. Admin work is edited per-tree. Shop rows are authored per-tree because `Components` differs. |
| The per-run product must survive a **lobby → game teleport**, and `Profiles.recordPurchase` already guarantees exactly-once *and* durable-on-disk before the receipt is consumed | `Profiles:239-291` | The charge is a **profile field**, granted by the same machinery gold packs use. No new idempotency code. |

Also confirmed by reading, so no work is needed to satisfy them:

- **Not lootable at camps** — `ExcursionServer:2258` picks the crate weapon from an explicit
  `if tier % 2 == 0 then "Shotgun" else "Pistol"`. Adding an item to `ItemDefs` cannot make it drop.
- **Not buyable with Salvage** — `ShopDefs.Order` (`ShopDefs:47`) is an explicit allow-list of 8 row ids.
  A new `ItemDefs` entry never appears there.
- **Hotbar + ammo signals** — `InventoryHud:278` already iterates `ItemDefs.Items` and connects every
  `ammoAttr` change signal, so the M16 slot and its round count render with no change to that file.
- **Mobile trigger** — `TouchFire` fires **one event per tap** (`TouchFire:76`), which is exactly one
  burst per tap. No change.

---

## 1. Definition of "a run"

The GAME place **is** the run: it is a reserved server per party, and `RunServer` returns everyone to the
lobby when it ends. So *"once per run"* == *"once per game-place session"*, and the per-run charge is
consumed **when the player joins the game place** (not at `Workspace.RunStarted`).

That is deliberate and it is the friendlier reading: players walk the crash-site camp before anyone
unties, and a paid gun that only appears after the boat leaves would read as broken. `InventoryService.seed`
already runs on `PlayerAdded` for the same reason.

---

## 2. Stats — agreed "rifle-strong"

```
M16   14 dmg x 20 bullets @ 0.10 s = 280 per burst · range 250 · 2.0 s cycle -> 140 dps
```

For the record, against what already exists:

| Weapon | Damage | Cycle | dps | Range | Ammo source |
|---|---|---|---|---|---|
| Pistol | 20 | 0.22 s | 91 | 220 | loot + Salvage |
| **M16** | **14 × 20** | **2.00 s** | **140** | **250** | **Robux only — 30 bursts/run** |
| Shotgun | 24 × 6 | 0.70 s | 206 | 95 | loot + Salvage |
| Turret | 75 | 0.30 s | 250 | 350 | boat cargo (gunner seat only) |

The M16 wins on **range and not having to close**, loses on raw dps to the shotgun, and is hard-capped at
30 bursts a run with **no way to top up**.

⚠️ **The lockout is NOT `fireInterval`.** An earlier draft of this plan said the burst is its own cooldown
via `fireInterval = 2.0`; the reviewer proved that wrong — `WeaponServer:128-129` multiplies it by
`0.965 ^ SkillGun`, so max Gun Discipline turns a 2.0 s lockout into 1.40 s and overlaps two bursts. The
lockout is a **burst-owned latch** instead. See §0b.

⚠️ **This is the second `power = true` item we sell**, after the Armored Boat. `MonetizationDefs`' own
header says *"Do not use it as precedent: nothing else here may set `power = true`"* and `GAME.md:366` says
the same. Both get an explicit note recording that this is a deliberate owner decision, not drift — so the
next person to read that rule sees the exception rather than concluding the rule was never real.

---

## 3. Monetization plumbing

### 3.1 `MonetizationDefs.luau` — **both trees, byte-identical**

- `GamePasses` += `{ key = "m16Lifetime", gamePassId = 1954603618, robux = 150, name = "Lifetime M16", power = true, blurb = "Start every run with the M16 + 30 rounds" }`
- new table `MonetizationDefs.RunGrants` — per-run loadout charges, held on the profile:
  `{ key = "m16", productId = 3709767395, robux = 30, name = "M16 (this run)", itemId = "M16", rounds = 30, passKey = "m16Lifetime", blurb = "..." }`
- new `MonetizationDefs.runGrantForProduct(productId): string?` — the third receipt route.

`RunGrants` is a **separate table from `Products`** on purpose: `Products` means "hand off to the
`GrantProduct` hook", and that hook is single-owner (§0). Keeping them apart is what stops the M16 from
overwriting self-revive.

It is also written generically so the **Bazooka** — already created on the Hub (`1956512376` / `3709767468`)
— becomes one data row plus one `ItemDefs` entry later, with no new plumbing. Nothing about the Bazooka is
built in this job.

### 3.2 `ProfileConfig.luau` — **both trees, byte-identical**

- `default()` += `runGrants = {}` — unspent per-run charges, `{ [key] = count }`.
- `migrate()` += the matching additive `if type(data.runGrants) ~= "table" then data.runGrants = {} end`.
- `ProfileConfig.RUN_GRANT_KEYS = { "m16" }` — so `Profiles._publish` can mirror them without
  `Profiles.luau` gaining a dependency on `MonetizationDefs`.

### 3.3 `Profiles.luau` — **both trees** (keeping the existing `hasSeen`/`markSeen` divergence)

- `_publish` += `player:SetAttribute("RunGrant_" .. key, count)` for each `RUN_GRANT_KEYS` entry.
  Same mirror-to-attribute pattern gold/`RiverScore`/`BoatPaint` already use, so both shops and the
  in-game consumer read it for free and it **replicates the moment a receipt lands mid-run**.
- `Profiles.addRunGrant(player, key, n)` — increment + `_publish`.
- `Profiles.takeRunGrant(player, key): boolean` — decrement one if available, `_publish`, return whether
  it spent. This is the *only* consume path.

### 3.4 `MonetizationServer.server.luau` — **both trees, byte-identical**

One new branch in `processReceipt`, between the gold-pack branch and the utility-product branch:

```lua
local runKey = MonetizationDefs.runGrantForProduct(info.ProductId)
if runKey then
    local ok = Profiles.recordPurchase(plr, info.PurchaseId, function()
        Profiles.addRunGrant(plr, runKey, 1)
    end)
    return if ok then PurchaseGranted else NotProcessedYet
end
```

**Why this branch and not the hook.** A hook grant returns `false` in the place that can't honour it, so a
lobby purchase would sit unconsumed waiting for Roblox to re-deliver the receipt *while the player happens
to be in the game place*. A profile field is granted **once, in whichever place took the money, durable on
disk before `PurchaseGranted` is returned** — and then the game place spends it. Buying in the lobby and
buying mid-run become the *same code path*, which is the only reason the "applies to your next run"
requirement is cheap.

---

## 4. The weapon

### 4.1 `ItemDefs.luau` (game tree)

New fields on `ItemDef`: `burstDuration: number?`, `burstInterval: number?`. Presence of `burstDuration`
is what makes a gun a burst gun — nothing else branches on the item id.

```lua
M16 = {
    name = "M16", kind = "Gun", color = Color3.fromRGB(52, 56, 50),
    ammoAttr = "AmmoM16",
    damage = 14, range = 250, pellets = 1,
    spread = 0.012,          -- a touch of scatter: 20 identical rays is a laser, not a rifle
    fireInterval = 2.0,      -- ⚠️ NOT the lockout — WeaponServer scales this by 0.965^SkillGun.
                             --    The real lockout is the burst latch. Kept so the pre-burst gate
                             --    still rejects a mashed trigger cheaply.
    burstDuration = 2.0,
    burstInterval = 0.10,    -- 20 bullets
    ammoOnLoot = 30,         -- one "round" = one 2 s burst
    -- ⚠️ NO `ammoPerCrate` ON PURPOSE — that field is what prices a gun's ammo at the trading post
    --    (ShopDefs:52) and tops it up from a camp crate. The M16 is Robux-only for now.
}
```

### 4.2 `WeaponAssets.luau` (game tree) — art + audio

`ART.M16` with `model = "M16"`, `sound.fire = { id = "rbxassetid://138005496001979", ... }`,
`sound.empty` reusing the shared dry-fire `75733077651437`.

**Measured, not guessed** — the file's own header records three failed attempts at guessing these. The mesh
is now in the library (§7) and was profiled from **29 264 actual vertices** via `EditableMesh`, sliced along
its long axis:

```
slice |  x-centre | height | thick | verts
  1   |  -0.1610 | 0.0521 | 0.0243 | 2707   <- butt plate
  3   |  -0.1024 | 0.0281 | 0.0177 |  362      stock neck / buffer tube
  6   |  -0.0146 | 0.1171 | 0.0213 | 4434   <- TALLEST: carry handle + magazine + grip
  8   |  +0.0439 | 0.0245 | 0.0256 | 3591      barrel
 11   |  +0.1317 | 0.0429 | 0.0211 | 2490   <- front sight post / gas block
 12   |  +0.1610 | 0.0094 | 0.0094 | 1537   <- MUZZLE (tapers to 0.0094)
```

- **Barrel axis = X, muzzle = `+X`, stock = `−X`.** Same convention as the Pistol and Shotgun, so
  `holdInChar = BARREL_FORWARD` — but asserted from this profile, not inherited from them.
- Source size **0.3512 × 0.1200 × 0.0286** (a Meshy import at a third of a stud). For a 5.0-stud held
  rifle — a little longer than the shotgun's 4.80, which is right, a rifle *is* longer than a sawn
  shotgun — `scale = 14.237`. Large, and documented as such with the source size, exactly as the
  Pistol's 0.316 and Shotgun's 0.842 are.
- `gripOffset` starts at `Vector3.new(-0.7, -0.30, 0)`: the grip sits at native x ≈ −0.05 (slices 4-6,
  where the magazine makes the profile jump to 0.081-0.117) → −0.7 studs at final scale. ⚠️ In absolute
  studs, applied **after** `Size *= scale`, so it does not ride the scale for free — the trap the
  Shotgun's own comment documents. Tuned on screen in Play.

### 4.3 `WeaponServer.server.luau` (game tree) — the authoritative burst

The single-shot path is **untouched** for Pistol/Shotgun. A `def.burstDuration` branch adds:

- **One ammo, one burst.** Ammo is deducted once, up front, exactly where it is today. A burst aborted
  part-way is **not** refunded — the round is spent at the trigger pull, as it is for every other gun.
- **The server owns the clock.** A `task.spawn`ed loop fires `burstDuration / burstInterval` rays at
  `burstInterval`. The client cannot lengthen a burst or shorten the gap.
- **🔴 The lockout is a burst-owned latch** — `burstUntil[player] = now + burstDuration`, checked before
  anything else and **not** multiplied by `0.965 ^ SkillGun`. This is the §0b defect. `lastShot` and the
  skill multiplier keep working unchanged for every other weapon.
- `PlayerRemoving` clears the latch **and** signals the running loop to stop. Today it only clears
  `lastShot` (`:214-216`), which for a burst weapon would leave a `task.spawn`ed loop firing with a stale
  `char` after the player has gone.
- **The burst aborts** (and the sound stops) if mid-burst the player stops holding the M16, is downed or
  killed, becomes `Busy` (carrying a crate), sits at the helm or turret, or leaves. `canShoot` is
  re-checked every bullet, not once at the trigger pull — a 2 s window is long enough for all of those to
  happen, and none of them may leave a gun firing on its own.
- **Damage numbers are batched.** `CombatFx.hit` is documented as *one event per target per shot* because
  6 pellets × 6 players is already 36 remotes; 20 bullets would be worse. The existing per-enemy `tally`
  is kept **across the whole burst and flushed every ~0.3 s**, so an enemy under sustained fire shows a
  rising ticker (~6 numbers per burst) instead of 20 stacked labels or one silent 2 s wait.
- **Audio: one `Sound`, started at burst start, stopped at burst end.** See §0. ⚠️ `cue()` closes over the
  `HeldItem` captured at trigger time, and `InventoryService:130-132` **destroys and rebuilds `HeldItem`**
  on every equip and respawn — so the stop path must re-find the Sound and tolerate it having been
  destroyed, or switching slots mid-burst orphans a 3.9 s clip that plays on forever.

**Aim tracking.** A burst you cannot sweep is 20 bullets into whatever you first clicked. A new
`UnreliableRemoteEvent AimWeapon` carries the client's live aim point during a burst; the server keeps the
latest and re-raycasts from the shooter's own root toward it, capped at `range` — i.e. **exactly as
trustworthy as the aim point the single-shot path already accepts**, and it degrades to "pinned to the
initial aim" if updates stop. Same shape as the turret's existing `GunAim` unreliable remote.

### 4.4 `WeaponClient.local.luau` (game tree) — local feel

- On a burst weapon, run a **local** 2 s loop drawing the muzzle flash + tracer per bullet and pushing the
  current aim over `AimWeapon`. Both sides read `burstInterval` from `ItemDefs`, so neither hand-copies it.
- **Aim is re-sampled per bullet**, so tracers follow the pointer as the player sweeps. ⚠️ The live-pointer
  sampler must use `ViewportPointToRay` (`GetMouseLocation` is viewport space) while the existing click
  path uses `ScreenPointToRay` on `input.Position` (screen space, includes the topbar inset) — this file's
  own comment at `:56` is why that distinction is called out here. The existing single-shot path is not
  touched.
- **Local trigger lockout** for the burst duration. Without one, every tap during the 2 s window passes
  `reticleShown()` and `haveAmmo()`, sends a remote the server discards, and **draws a muzzle flash and a
  tracer** — ~10 flashes and 10 tracers with the ammo counter frozen, which is precisely the "the gun does
  not fire" confusion the Job #084 notes at `WeaponClient:152-160` exist to eliminate. On touch this is the
  common case, because `TouchFire:73-74` is one-shot-per-tap by design and there has never been a cooldown
  long enough to notice. During the lockout the reticle uses the **existing** blocked vocabulary rather
  than a new one.
- A modest **reticle bloom** while the burst is live — the player needs to see the gun is firing without
  borrowing the yellow that already means "hands full".
- Replace the two hardcoded `GetAttributeChangedSignal("AmmoPistol"/"AmmoShotgun")` connections with a loop
  over `ItemDefs.Items`, the way `InventoryHud:278` already does. Hardcoding them is why a new gun's ammo
  would silently fail to repaint the reticle.

### 4.5 New: `sync/ServerScriptService/Inventory/RifleGrant.server.luau` (game tree)

The one place a paid weapon enters a loadout. On join (after `InventoryService.seed` and once the profile
is ready) and on change thereafter:

0. **`M16Granted` is checked FIRST and the grant is idempotent.** `MonetizationServer:108-117` sets
   `Owns_<key>` a *second* time on `PromptGamePassPurchaseFinished`, and `InventoryService.grant:365-372`
   turns a repeat grant into a silent `+ammoOnLoot` top-up — so an unguarded re-fire hands out **60 rounds
   instead of 30** and presents as a rounds bug, not a purchase bug. (Reviewer finding, verified.)
1. `Owns_m16Lifetime == true` → grant `M16` + 30 rounds. Watches `GetAttributeChangedSignal`, because
   `checkPasses` waits up to **20 s** for the profile before calling `UserOwnsGamePassAsync`
   (`MonetizationServer:85-96`) while `InventoryServer.setupPlayer` seeds on `PlayerAdded` — so the
   attribute reliably lands *after* seed. Sampling it once would give every pass owner an empty loadout.
   `ItemDefs:60-62` already states this rule for `Owns_extraSlots`.
2. else `RunGrant_m16 > 0` → `Profiles.takeRunGrant(player, "m16")`, and on success grant the same.
   Watching the attribute is what makes an in-run purchase grant instantly *and* a lobby purchase land on
   join, through one branch.
3. Sets `player:SetAttribute("M16Granted", true)` — what both shops read to disable the per-run row.
   A dedicated attribute rather than scanning slots, because `InventoryService.drop` lets a player throw
   the rifle away and a slot scan would then sell them a second one in the same run.
4. **Skips a `Dead` player.** `RunServer:59` sets `CharacterAutoLoads = false` and death is permanent
   (`:107-114`, character destroyed after 1.5 s), so `onCharacterAdded` never fires again — granting to a
   spectator writes slot attributes nothing will ever render, and burns the charge. The charge stays banked.

Grants go through `InventoryService.grant`, which already handles "no free slot" (returns false) and
"already own it → top up ammo".

⚠️ **Not** under `lobby/sync/ServerStorage/` — `lobby/default.project.json` maps no `ServerStorage` at all,
and the `InventoryService.luau` sitting there is a **dead pre-Job-067 fork** that never loads (it requires
a `ReplicatedStorage.Inventory.ItemDefs` the lobby tree does not have). Anything put there silently never
runs. This is what `MonetizationServer:22-23` is warning about.

---

## 5. Both Robux shops

`RobuxShop.local.luau` in **both** trees gains a `RIFLES` section under `Passes`, keeping the two files the
near-copies their headers require:

| Row | Source | Badge | Button states |
|---|---|---|---|
| **Lifetime M16** — 150 R$ | `GamePasses` (existing loop, no new code) | `Theme.icon.rifle` | price → `OWNED` |
| **M16 (this run)** — 30 R$ | new `RunGrants` loop | `Theme.icon.rifleAmmo` (the clip) | price → `THIS RUN` / `NEXT RUN` / `OWNED` |

The per-run row's disabled states, and why each exists:

- **`OWNED`** when `Owns_m16Lifetime` — never sell a per-run charge to someone who owns it forever.
- **`THIS RUN`** (game place) when `M16Granted` — the "one purchase per run" rule, enforced in the UI.
- **`NEXT RUN`** (lobby) when `RunGrant_m16 > 0` — an honest label for a charge that is paid for and
  waiting, rather than a live button that would take the money twice.

All three follow the file's existing `refresh()` discipline: **default to not-owned**, re-decide from
scratch inside one function, and let the async price lookup and the async attribute land in any order.

Enforcement is **disabling the button before the prompt**, because refusing *after* the money is taken is
not something `MarketplaceService` can do — the only lever is declining to consume the receipt, which makes
Roblox re-deliver it forever rather than refund. So the row also **honours any receipt that arrives anyway**
(it banks a charge for the next run rather than dropping it).

⚠️ **Two traps in these two files specifically:**

1. **Do not render `MonetizationDefs.Products`.** Neither shop does today, deliberately
   (`MonetizationDefs:21-23` — contextual buy points only). A three-line `for _, p in ipairs(Products)`
   would also list **Self Revive at 20 R$, buyable at full health** — which `MonetizationDefs:26-27` says
   must never happen, and whose grant closure returns `false` forever (`PlayerCombat:50-53`), so the
   receipt is never consumed and Roblox re-delivers on every join. The new `RunGrants` table exists partly
   to keep that loop impossible.
2. **Author each row against its own tree.** `Components.luau` has diverged (§0b): the lobby has a `chip`
   button variant the game tree lacks, and the game's `Components.button` resolves an unknown variant to
   **green primary, silently** (`:187`). Stick to `primary`/`secondary`/`gold`/`danger`, which both have.

`Theme.luau` (both trees): `icon.rifle = 87494055704448`, `icon.rifleAmmo = 134307949592665`,
`itemIcon.M16 = "rifle"`, `productFallbackIcon.m16Lifetime = "rifle"` / `.m16 = "rifleAmmo"`.

⚠️ `RobloxPassM16.png` → `118709115773836` is **deliberately not** wired into `productIcon`. It is
1254×1254 **RGB with no alpha channel** (checked in the PNG's IHDR), i.e. exactly the opaque Hub-thumbnail
matte that §5.1 of ASSETS.md says *"renders as a white blob inside the round row badges — never swap a Hub
id into the GUI"*. It stays recorded as the store-listing art. The transparent `assault-rifle` /`bullet`
uploads are what the GUI draws.

---

## 6. Admin panel — **two actions, not one**

The reviewer's point: `Profiles.recordPurchase` refuses unless `isPersisting` (`Profiles:240-242`) and
Marketplace prompts do not complete in Studio, so **neither purchase path can be exercised in Studio**.
One "give me the gun" button would leave the entire lobby→run half of the feature untested. So:

**Game tree only** — the immediate grant:
- `AdminServer` `give` gains `kind == "m16"` → `InventoryService.grant` + top up to the requested rounds.
- `AdminClient` `actions` gains `{ label = "Give M16 + 30 rounds", icon = "rifle", kind = "m16", amount = 30 }`.

**Both trees** — the banked charge, so the lobby→run path is testable end to end:
- `give` gains `kind == "m16Charge"` → `Profiles.addRunGrant(target, "m16", 1)`.
- Label: `"Bank M16 charge (next run)"`. This is a *shared* grant, like gold and score.

`AdminServer` does not currently require `InventoryService`; the game copy will (it is a server-only module
in `ServerStorage`, and server-side `require` is cached, so this shares the one instance the rest of the
inventory uses rather than making a second). The **lobby** copy must not — there is no `ServerStorage` in
that place — so `m16Charge` is profile-only and `m16` is game-tree-only.

⚠️ `AdminServer` + `AdminClient` have **deliberately diverged** between trees (`AdminClient:6-11`), so each
copy is edited in place. **Never copy one over the other** — the game copies carry ~280 lines of
game-only tooling (`tpFirstCamp`, `tpEndBase`, the Job #112 cheat toggles). While I am in these files I will
also correct the three **stale headers** that still claim byte-identity (§0b).

---

## 7. Human / Studio step

One item, and it is the only thing I cannot do from disk: **`ServerStorage.AssetLibrary.Weapons` is not
Rojo-synced**, so the M16 mesh has to be put into the place and the place saved.

I can do this over Studio MCP (both places are open — I see `Last River COOP Game` and the lobby) — insert
`84134973846203`, pull the `MeshPart` out of the Meshy `Scene` wrapper, rename it `M16`, set
`CollisionFidelity = PreciseConvexDecomposition`, park it beside `Pistol`/`Shotgun`, scan it for scripts
per the asset policy, and delete the wrapper. **It changes your open place, so I will describe exactly what
I am about to do and ask before doing it.** You save the place afterwards, or the library entry vanishes.

Everything degrades until then: `InventoryService.updateHeldVisual` falls back to the coloured greybox
part, so the M16 is fully testable before the mesh lands.

---

## 8. Verification — in Play, and able to fail

Per GROUND-RULES §7. Each check names what failure looks like, or it is decoration.

| # | Check | Fails if |
|---|---|---|
| 1 | Admin-grant the M16, fire once. Read the **server log** for per-bullet `[Weapon] HIT` lines. | Fewer than ~20 lines, or the lines keep coming after 2 s. |
| 2 | `AmmoM16` after one burst. | Anything other than `−1`. |
| 3 | Mash the trigger during a burst. | A second burst starts, or ammo drops by more than 1. |
| 4 | Sweep the pointer across two targets mid-burst. | Both take damage only if aim tracking works; all 20 rays landing on the first target means `AimWeapon` is not being read. |
| 5 | Get downed / pick up a crate mid-burst. | The gun keeps firing. |
| 6 | Damage numbers over a target under sustained fire. | 20 stacked labels (batching broken) or none until the burst ends (flush interval broken). |
| 7 | Audio. | The 3.9 s clip restarting per bullet, or still playing after the burst. |
| 8 | Buy the per-run product **in the lobby** with a real prompt, teleport, join the game place. | The M16 is absent, or `RunGrant_m16` is still > 0 after the grant (double-spendable). |
| 9 | Buy it **in-run**. | It does not appear until rejoin. |
| 10 | Both shops, before and after. | The per-run row stays live after a purchase (sellable twice), or reads `THIS RUN` to a player who never bought it. |
| 11 | **Self-revive still works** — buy it while downed after all of the above. | It is broken → something claimed `GrantProduct`, which is the whole reason §3 avoids that hook. |
| 12 | Hotbar slot + round count, and the reticle colour going red at 0 rounds. | No icon (missing `itemIcon` key) or a stale count. |

Checks 8–9 need a **published** place (`MarketplaceService` prompts do not complete in Studio) and 8 needs
DataStore access, so they are the last two and I will say plainly if they end up unverified rather than
implying they passed.

---

## 9. Files

**Both trees, edit identically** (`sync/…` and `lobby/sync/…`):

- `ReplicatedStorage/Progression/MonetizationDefs.luau`
- `ReplicatedStorage/Progression/ProfileConfig.luau`
- `ReplicatedStorage/UI/Theme.luau`
- `ServerScriptService/Progression/MonetizationServer.server.luau`
- `ServerScriptService/Progression/Profiles.luau` *(keeping the existing Job #098 divergence)*
- `StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` *(near-copies, not identical — the 3
  documented differences stay)*

**Game tree only** (`sync/…`):

- `ReplicatedStorage/Inventory/ItemDefs.luau`
- `ServerStorage/Inventory/WeaponAssets.luau`
- `ServerScriptService/Combat/WeaponServer.server.luau`
- `StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau`
- `ServerScriptService/Inventory/RifleGrant.server.luau` **(new)**
- `ServerScriptService/Progression/AdminServer.server.luau`
- `StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau`

**Docs**: `ASSETS.md` (§3.2 weapon audio, §5.1 monetization art, a new §5.2c for the two rifle icons),
`GAME.md` (the monetization table + the second `power = true` exception).

**Not touched, and that is the point**: `ShopDefs.luau`, `ExcursionServer.server.luau`, `CampDefs.luau`,
`InventoryHud.local.luau`, `TouchFire.luau`, `PlayerCombat.server.luau`.

---

## 10. Open risk

The M16 is **the first thing we sell that makes the buyer personally stronger**. The Armored Boat's excuse
is that it buffs the whole crew; this does not have that excuse, and a 150 R$ pass that hands one player
140 dps at 250 studs will be visible to the four people next to them who did not pay. The 30-burst cap and
the absence of any way to buy more is the only thing holding the line.

Your call, and it is recorded as your call — I am flagging it, not blocking it. If it plays badly the
cheapest lever is `ammoOnLoot` (bursts per run), not the damage.

---

## 11. The one question left for you

Everything else above is decided. This one is a balance/UX call that the reviewer surfaced and I will not
make on your behalf.

**Does Gun Discipline speed up the M16?**

`SkillDefs:24` sells the skill as *"Shoot faster (guns & turret)"*, for Gold, and `WeaponServer:128-129`
applies it to every gun by multiplying `fireInterval` by `0.965 ^ level`. Applied to a burst weapon it
shortens the 2 s lockout to 1.40 s at level 10 and overlaps two bursts — so it cannot simply stay as-is.

- **A — M16 is exempt** (my recommendation). The lockout is a flat 2.0 s for everyone. The burst stays
  exactly the 2 s you specified, and the paid weapon does not also scale with a paid skill. Cost: the
  skill's blurb becomes very slightly untrue for one of four guns.
- **B — the skill shortens the GAP but never the burst.** Burst stays 2.0 s of fire; the cooldown *after*
  it shrinks with skill (2.0 s → 1.40 s of downtime becomes 0 s → and then you'd need a separate gap
  value). More faithful to the skill, more moving parts, and it makes the strongest weapon stronger for
  players who also bought skills.
- **C — the skill scales bullets-per-burst instead** (same 2 s, tighter interval → up to ~28 bullets).
  Keeps the burst length exact and honours "shoot faster" literally, but raises peak burst damage from
  280 to ~392 on a weapon that is already the §10 risk.

**DECIDED: A — the M16 is exempt.** Recorded in `SkillDefs`' own comment so the next person does not read
the blurb and assume it applies to everything, and verified in Play (13 trigger pulls at `SkillGun = 10`
spent exactly one round). Plan agreed and implemented — see `final-summary.md`.
