# Job #117 — Final summary

**Project**: `roblox.jungle` · **Completed**: 2026-08-25 · **Status**: implemented + verified in Play

The M16: the first weapon in Last River sold for Robux, and the first **burst** weapon. One trigger pull
fires 20 bullets over 2 s for one round; 30 rounds a run, from a 150 R$ lifetime pass or a 30 R$ one-run
charge, sold in both Robux shops.

---

## 1. What the reviewer caught (GROUND-RULES §8)

One independent reviewer, given the requirement and the repo but **never** this plan's approach. It found a
defect the plan would have shipped, plus four gaps. Every claim was re-verified before acting on it.

### 🔴 The defect: Gun Discipline silently broke the 2-second rule

`WeaponServer` computes `interval = (def.fireInterval or 0.22) * (0.965 ^ SkillGun)`. The plan had asserted
that `fireInterval = 2.0` **was** the lockout. Measured, it is not:

```
SkillGun  0 -> 2.000 s      SkillGun 10 -> 1.401 s   (SkillDefs.MAX_LEVEL = 10)
```

At max Gun Discipline two bursts overlap for 0.6 s — ~6 extra bullets, ~84 extra damage, no error, nothing
in the log. And **invisible in exactly the state a tester is in**: Studio dev profiles start empty by
decision, and the fix for that is the admin panel's one-click "MAX ALL Skills".

The lockout is now a **burst-owned latch** (`burstUntil`), unscaled by anything. Verified below.

### The four gaps

| Gap | Verified how | What changed |
|---|---|---|
| `Components.luau` has **already diverged** between trees (game 1106 lines LF, lobby 1309 CRLF; the lobby has a `chip` button variant the game lacks, and an unknown variant resolves to green `primary` **silently**) | `wc` / `file` / `grep` | The plan had wrongly listed it as byte-identical. Shop rows are authored per-tree and use only `primary`/`secondary`/`gold`/`danger`. |
| The Robux kiosk exists **only at the crash site**; `StagingServer:220` clears `HubSpawn` and sails the crew away. There is no kiosk on the river | read `StagingServer:204-225` | "Buying in-run" is really "buying during staging". Consume-at-join is the *only* correct point, not merely the friendlier one. |
| `Owns_<key>` is set a **second** time on `PromptGamePassPurchaseFinished`, and `InventoryService.grant` turns a repeat into a silent `+ammoOnLoot` | read both | A mid-run pass purchase would have granted **60 rounds, not 30**, presenting as a rounds bug. `Granted_<key>` is now checked *before* granting. Verified below. |
| The purchase path **cannot be exercised in Studio** (`recordPurchase` needs `isPersisting`; Marketplace prompts never complete) | read `Profiles:240-242` | The admin panel got **two** actions, not one, so the lobby→run half is testable. |

### Confirmed correct, unchanged

The reviewer independently reached the plan's four load-bearing conclusions: the `GrantProduct`
single-owner trap, the charge belonging on the profile (TeleportData carries **one table for the whole
party** — no per-player slot), the charge being a **count not a boolean**, and the write having to happen
**inside** `recordPurchase`'s `grant` closure so its yield-until-`LastSavedData` covers it.

---

## 2. Design decisions that are not obvious

**`GrantProduct` is deliberately not used.** `MonetizationServer` creates one `BindableFunction` and
`PlayerCombat:64` assigns `OnInvoke` outright for `selfRevive`. A second claimant does not error — it
*replaces* the first, load order is undefined, and the loser returns false forever → `NotProcessedYet` →
Roblox re-delivers on every join. Copying the self-revive pattern (which `MonetizationServer`'s own comment
points you toward) would have **silently broken paid self-revive**. Per-run charges take a third receipt
route straight onto the profile instead.

**Per-run charges are their own table, not `Products`.** Neither shop has ever rendered `Products`
(contextual buy points only). A three-line loop over it to get the M16 onto a shelf would also have listed
**Self Revive, 20 R$, buyable at full health** — which that table's own comment forbids, and whose grant
returns false forever. `RunGrants` makes that mistake unreachable from the shop files.

**"Per run" = per game-place session.** The game place *is* the run: reserved server per party,
`StagingServer` only ever sets `RunStarted` true, `RunServer` teleports everyone out and lets the server
drain. So a player attribute is per-run for free — the idiom `Salvage` and `InvSeeded` already use.

**The fire clip is 3.888 s of sustained auto-fire**, measured via `Sound.TimeLength` rather than inferred
from the filename. Played once per burst and stopped at 2 s. Restarting it per bullet would relaunch it 20
times in 2 s — the cicada-stacking mistake `GameSoundscape` documents.

**Orientation and scale were measured from 29 264 vertices** via `EditableMesh`, sliced along the long
axis: butt plate at −X, tallest slice mid-body (carry handle over magazine), front sight post bump, muzzle
tapering to 0.0094 at **+X**. Same convention as the other two guns, but asserted for *this* mesh — the
`WeaponAssets` header records three separate occasions when guessing it was wrong.

**Aim tracking.** A burst you cannot sweep is 20 bullets into whatever you first clicked. A new
`AimWeapon` `UnreliableRemoteEvent` carries live aim; the server still re-raycasts from the shooter's own
root capped at `range`, so it is exactly as trustworthy as the aim point `FireWeapon` already accepted.

**Damage numbers are windowed, not per-bullet or summed-to-the-end.** `CombatFx`'s header forbids
per-pellet events (36 remotes for a shotgun volley across a full crew); 20 bullets would be worse. One
summed number 2 s late is no good either — `CombatFeedback` labels live 0.9 s. So the tally is flushed on a
0.3 s window: ~7 rising numbers per burst.

---

## 3. Balance

```
M16   14 dmg x 20 bullets @0.10s = 280 per burst · range 250 · 2.0 s cycle -> 140 dps
```

| Weapon | Damage | Cycle | dps | Range | Ammo |
|---|---|---|---|---|---|
| Pistol | 20 | 0.22 s | 91 | 220 | loot + Salvage |
| **M16** | **14 × 20** | **2.00 s** | **140** | **250** | **Robux only — 30 bursts/run** |
| Shotgun | 24 × 6 | 0.70 s | 206 | 95 | loot + Salvage |
| Turret | 75 | 0.30 s | 250 | 350 | boat cargo, gunner seat only |

Gun Discipline **does not apply to the M16** (owner's decision): the burst stays exactly 2 s for everyone
rather than stacking a paid skill on a paid weapon. Recorded in `SkillDefs`' own comment.

⚠️ **The M16 is the second `power = true` item we sell, and it did not earn it the way the Armored Boat
did.** The boat's exemption rests on the buff being **crew-wide**; the M16 is a solo weapon in one buyer's
hands, the best sustained gun on foot, un-earnable at any price in Salvage or loot. That objection was put
to the owner and they chose to ship it. Recorded as a decision in `MonetizationDefs`, `GAME.md` and here —
not folded in as though routine. **The only thing holding the line is 30 bursts a run with no way to buy
more** (no camp crate, no trading-post row, no `ammoPerCrate`). If it plays badly the lever is
`ammoOnLoot`, not `damage`.

---

## 4. Verified in Play (GROUND-RULES §7)

Driven end-to-end over Studio MCP. Every check states what failure would have looked like.

| # | Check | Result |
|---|---|---|
| 1 | **Burst length + damage.** HP curve on an unkillable target | 42→98→140→182→224→266→**280** then flat. **Exactly 20 bullets × 14**, over ~2.2 s ✅ |
| 2 | **One round per burst** | `AmmoM16` 30 → 29 ✅ |
| 3 | 🔴 **The reviewer's defect.** `SkillGun = 10`, 13 trigger pulls across 1.88 s, straight through the 1.401 s mark | **1 round spent, 280 damage, 20 bullets.** The latch ignored Gun Discipline ✅ |
| 4 | **Mid-burst abort.** Switch to the Axe at t=0.62 s | Stopped at **84 damage (6 bullets)** and stayed there — never reached 280. Round still spent, by design ✅ |
| 5 | **Aim tracking.** Sweep onto a second target mid-burst | 9 bullets into A, **11 into B**, combined exactly 280 for one round ✅ |
| 6 | **Damage batching** | **8 `CombatFeedback` events** summing 336 across a burst + a partial — not 20, not 1 ✅ |
| 7 | **Audio stops at burst end** | `fire` Sound `IsPlaying = false` at t=2.7 s. A 3.888 s clip would still be playing ✅ |
| 8 | **Nothing auto-fires.** 6 idle seconds, no input | ammo held at 30, damage 0 ✅ |
| 9 | **Lifetime pass grant** (the user really owns pass `1954603618`) | `MonetizationServer` → `RifleGrant` on join, unaided: slots `Axe, Torch, M16`, `AmmoM16=30`, logged `[RifleGrant] johnygorsky10 -> M16 (lifetime pass)` ✅ |
| 10 | 🔴 **Double-grant trap.** Re-set `Owns_m16Lifetime` (what a mid-run purchase does) | **stayed 30, not 60** ✅ |
| 11 | **Seed race.** M16 must not land in slot 1 | slots read `Axe, Torch, M16` — `awaitSeeded` held ✅ |
| 12 | **Per-run charge, game place** | banked → consumed same frame → M16 + 30 rounds, `RunGrant_m16` back to **0** (not double-spendable) ✅ |
| 13 | **Per-run charge, lobby** | banked → **stays at 1** (nothing there consumes it) ✅ |
| 14 | **Shop row states** | `OWNED` (pass owner) · `THIS RUN` (granted, game place) · `NEXT RUN` (banked, lobby) · `R$ 150` live ✅ |
| 15 | **Hotbar** | slot 3 shows the rifle icon + round count; held item is a real **MeshPart**, not the greybox ✅ |
| 16 | **Startup consistency check** | printed nothing — shop's advertised 30 rounds matches `ItemDefs.ammoOnLoot` ✅ |
| 17 | **Analyzer**, both trees | clean. Proven able to fail: a deliberate broken copy reported both a SyntaxError and a TypeError ✅ |
| 18 | **No test residue** | zero leftover instances or attributes in the saved place ✅ |

### Not verified, and why

- **A real Robux purchase.** `MarketplaceService` prompts do not complete in Studio and
  `Profiles.recordPurchase` refuses without `isPersisting`. The grant *mechanism* was exercised through the
  admin actions (checks 12–13), which reach the same `Profiles.addRunGrant` a receipt reaches; the
  `ProcessReceipt` branch itself has not run for real. **Needs one 30 R$ purchase on the published place.**
- **Mobile.** `TouchFire` is one-tap-one-burst by design and was not changed, so no new touch surface was
  added — but this has not been measured in the Device Emulator.

---

## 5. Bug found and fixed mid-job (reported by the user)

> *"when i shoot from first person perpective i have big yellow square, looks ugly"*

**Not the muzzle flash** — that was the first suspicion and it was wrong (the emitter has a real
`sparkles_main` texture and makes a soft glow). Captured from the player's own camera before changing
anything: a **hard-edged** orange-yellow quad, i.e. geometry.

It was the **tracer**, which started at `Head.Position`. In first person the camera sits at the head, so
the part *enclosed the camera*, and a `Neon` part you are inside renders as a solid slab. The M16 made it
constant rather than a flicker: 20 tracers a burst at 0.05 s each covers most of the 2 seconds.

Fixed two ways: the tracer now starts at the **muzzle** (shared with the flash via a new `muzzleWorld`, and
more correct in third person too — a tracer should leave the barrel, not the eyeball), and the origin is
**re-based clear of the camera** when it would fall inside 2.5 studs (the greybox fallback item sits at the
chest, so the muzzle alone is not a guarantee).

**Verified:** 40 tracers from 2 bursts (independently confirming 20 client FX per burst), closest near-end
**3.36 studs** from the camera, **0 enclosing it**. Before/after captures from the same view.

⚠️ A first attempt at this check reported a false zero — it fired `FireWeapon:FireServer` directly, which
bypasses the client's `fire()` and therefore draws no FX at all. Re-run through real injected clicks. Worth
recording: the "before" yellow square came from the **user's own clicks**, not the test harness, which is
also what the unexplained ammo drift during testing was.

---

## 6. Icons

Set by the user after seeing both on screen: *"For Lifetime use pass icon, and one time use rifle icon"*.

| Row | Image | Note |
|---|---|---|
| Lifetime M16 | `99770814546746` | the pass store image the user supplied |
| M16 (one run) | `87494055704448` (`assault-rifle`) | also the hotbar glyph |

All four candidate ids verified in Studio via `GetProductInfo` → AssetTypeId 1 (Image), creator
`johnygorsky10`. ⚠️ **Three different images exist for this one pass and must not be substituted for each
other** — `118709115773836` (`RobloxPassM16.png`) is 1254×1254 **RGB with no alpha** and is Hub source art
only; `99770814546746` is the in-game store image; `87494055704448` is the glyph.

**Open cosmetic point:** the pass image has no alpha, so it renders as a **square inside the round badge**.
Legible, and it does read as a product. If it should be fixed, the fix is a transparent re-upload of the
same artwork — not a different icon. `Theme.icon.rifleAmmo` (`bullet`) is consequently registered but
unused, kept for a future rifle-ammo shop row.

---

## 7. Files

### Both trees, edited identically (`diff` silent — verified)
- `ReplicatedStorage/Progression/MonetizationDefs.luau` — the pass, `RunGrants`, `runGrantForProduct`
- `ReplicatedStorage/Progression/ProfileConfig.luau` — `runGrants` in `default()` **and** `migrate()`, `RUN_GRANT_KEYS`
- `ReplicatedStorage/Progression/SkillDefs.luau` — the M16 exemption, recorded
- `ReplicatedStorage/UI/Theme.luau` — `rifle`/`rifleAmmo`, `itemIcon.M16`, `productIcon.m16Lifetime`
- `ServerScriptService/Progression/MonetizationServer.server.luau` — the third receipt route

### Both trees, same insertion applied separately (pre-existing Job #098 divergence preserved)
- `ServerScriptService/Progression/Profiles.luau` — `_publish` mirror + `addRunGrant`/`takeRunGrant`/`getRunGrant`

### Both trees, edited per-tree (deliberately diverged — headers corrected)
- `ServerScriptService/Progression/AdminServer.server.luau` — `m16Charge` (both), `m16` (game only)
- `StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` — the rows
- `StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` — the "Buy for one run" section

### Game tree only
- `ReplicatedStorage/Inventory/ItemDefs.luau` — `M16`, `burstDuration`/`burstInterval`
- `ServerStorage/Inventory/WeaponAssets.luau` — `ART.M16` + the vertex profile
- `ServerScriptService/Combat/WeaponServer.server.luau` — the burst, the latch, windowed damage, audio stop
- `StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau` — burst FX, aim sampling, the tracer fix, and **every gun's** ammo signal instead of two hardcoded names
- `ServerScriptService/Inventory/RifleGrant.server.luau` **(new)**

### Docs
`ASSETS.md` (§3.2, §5.1, new §5.2c) · `GAME.md` (monetization table + the second-exception note)

### Not touched, and that is the point
`ShopDefs.luau`, `ExcursionServer.server.luau`, `InventoryHud.local.luau`, `TouchFire.luau`,
`PlayerCombat.server.luau`.

### Studio (not Rojo-synced — 🔴 SAVE THE PLACE)
`ServerStorage.AssetLibrary.Weapons.M16` — MeshPart from `84134973846203`, scanned (**0 scripts**), Meshy
`Scene` wrapper deleted, `CollisionFidelity = Box` / `RenderFidelity = Automatic` to match the other guns.

---

## 8. Findings logged, not fixed here

- **0030** (low) — the Robux shop stays open through the 30 s results screen; nothing closes it on
  `RunEnded`. The M16 rows are safe (guarded by `Granted_m16`), so out of scope.
- **0031** (med) — three admin file headers claimed byte-identity after diverging. Corrected in the files
  this job touched; the finding records the class of problem.

## 9. Left for the owner

1. **Save the GAME place** or the M16 library entry is lost.
2. **One 30 R$ purchase on the published place** to exercise `ProcessReceipt` for real (§4).
3. The pass-icon matte, if it bothers you (§6).
4. The Bazooka's four Hub ids are recorded in `ASSETS.md` and wired nowhere. `RunGrants` was built
   generically so it is one data row plus one `ItemDefs` entry — **not** started here.
