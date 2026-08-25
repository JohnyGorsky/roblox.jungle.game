# Job #118 — Final summary

**Project**: `roblox.jungle` · **Completed**: 2026-08-25 · **Status**: implemented + verified in Play

The Bazooka: the second weapon in Last River sold for Robux, and the **first projectile weapon**. One
trigger pull lobs a rocket that flies a visible arc, lands on a marked point after exactly 4 seconds, and
blasts a 30-stud radius for 300 damage. 6 rockets a run, 5-second reload, from a 250 R$ lifetime pass or an
80 R$ one-run charge, sold in both Robux shops.

It also closes a live money hole: pass `1956512376` and product `3709767468` have been **`IsForSale` and
wired to nothing** since Job #117 shipped. A game pass is buyable from the experience store page without
entering the game, so that listing has been taking 250 R$ and delivering nothing.

---

## 1. What the reviewer caught (GROUND-RULES §8)

One independent agent, given the requirement and the repo and told **nothing** of the plan. It
independently reached the plan's two load-bearing conclusions — the `fireInterval` trap, and that a
server-moved anchored part must not be used for the projectile — and then found **eight things the plan did
not have**. Every claim was re-verified in the file before being acted on.

| # | What it found | What changed |
|---|---|---|
| 1 | **`damage = 300` is a loaded gun.** `WeaponServer:380` falls through to hitscan `volley()` for any `kind == "Gun"` no earlier branch claims — so a lost or reordered projectile branch ships a **300-damage instant-hit 300-stud sniper rifle** that looks exactly like the weapon working | The blast number moved to **`blastDamage`**; `damage` is left **unset**, so that same mistake degrades to a 20-damage pistol shot. The failure mode is chosen rather than left to luck |
| 2 | **Foliage leaves are `CanQuery` and stop rays** (`findings/0023`), and under streaming the *client has not loaded them while the server has* — so a client preview and the server impact diverge by tens of studs | Both sides exclude `Workspace.Foliage`. Removes the divergence at its root and is independently correct: a rocket punches through a fern |
| 3 | **Every new world part must be `CanQuery = false`**, or it stops other players' bullets, yanks the boat camera in, makes the aim ring **hit itself** and creep toward the camera, and reads as ground to the "am I aboard?" ray | Applied to every part the feature creates, and documented in `GroundRing`'s header |
| 4 | **`CombatFeedback` culls at 260 studs**; this weapon reaches 300 | Blast VFX is its own code, not routed through `CombatFx`. Accepted limitation logged as **finding 0033** |
| 5 | **Enemies are reaped mid-flight** — `CULL_BEHIND = 260` and the boat covers ~208 studs in 4 s | Confirms the re-scan-at-impact rule; added an explicit `Parent ~= nil` re-check |
| 6 | **Rocket sounds must not live on `HeldItem`** — `updateHeldVisual` destroys and rebuilds it on every equip and respawn | They live on the projectile |
| 7 | **`rocket_whistle` is 3.840 s against a 4.000 s flight** — 160 ms of silence immediately before impact | Starts at **t = 0.16 s**, so it ends *on* the blast |
| 8 | **A pass owner can buy a charge that is never spent** | Fixed — §3 |

### What it flagged that turned out to be the single most dangerous thing here

> *"A radius scan that looks for models with an `HP` attribute will kill the crew and the boat."*

**Verified, and it is exactly right.** A player's health is a character-**Model** attribute
(`PlayerCombat:108` `char:SetAttribute("HP", MAX_HP)`) and the boat's hull is `boat:SetAttribute("HP", …)`
(`EnemyServer:366`) — the *same attribute name* enemies use. The obvious implementation of area damage
wipes the landing party.

The blast therefore iterates `CollectionService:GetTagged` over `Enemy` / `CampGuard` / `Generator` — the
shape `MeleeServer:144-153` already uses. It cannot reach a player or the boat **by construction**, rather
than by a "skip players" filter a later edit could quietly drop.

It also pointed out that a Roblox **`Explosion` instance** would be the worst available choice, and that is
worth recording: enemies here take damage through an `HP` *attribute*, not a `Humanoid`, so an `Explosion`
would deal **zero** damage to every enemy in the radius while ragdolling the entire crew.

---

## 2. What TESTING caught that neither the plan nor the reviewer did

🔴 **The rocket's explosion was driven off `RenderStepped`, so an alt-tabbed player would never see it.**

Found by accident and then measured: mid-verification the client reported **`Heartbeat = 60/s`,
`Stepped = 61/s`, `RenderStepped = 0/s`** — the Studio window had gone behind another window and stopped
rendering. The aim ring froze at the world origin and `screen_capture` timed out.

That is not a Studio quirk to work around; it is a real player state. A player who alt-tabs, minimises, or
is occluded for the two seconds a rocket is in the air would have had:

- the rocket **freeze in mid-air** and then jump when they came back, and
- **the explosion never happen at all** on their screen — no flash, no shockwave, no sound — while the
  server dealt 300 damage regardless.

Two changes: the flight moved to **`Heartbeat`** (a world-space anchored part gains nothing from running
before the render and loses the guarantee of running at all), and the blast moved onto its **own
`task.delay`**, so it cannot be missed no matter what the frame loop is doing. The aim ring moved to
`Heartbeat` for the same reason. **Verified after the change with rendering still stalled**: ring tracking,
and all three blast FX parts created.

---

## 3. The inherited money bug that WAS fixed (owner's call)

**A Lifetime owner could buy a per-run charge that is never spent and never refunded.**

`MonetizationServer.checkPasses` waited up to 20 s for the profile and then wrote `Owns_<key>` **only when
the answer was true**. There was no "not owned" and no "the check has finished", so both shops had no way
to tell *"they don't own it"* from *"we don't know yet"* and showed a live buy button either way —
`RobuxShop:173-177` says so in its own comment. `RifleGrant:105-119` then prefers the free pass grant and
**never spends the charge**, which sits on the profile forever.

Fixed in both trees: `checkPasses` now publishes the result **either way** and sets a single
`PassesChecked` flag when the whole loop is done; per-run rows that have a `passKey` hold their button
disabled (`CHECKING`) until it lands. A failed `UserOwnsGamePassAsync` is left *unset* rather than written
false — a web hiccup must not become "definitely not owned".

⚠️ **Publishing `false` was checked before it was written**: every consumer in both trees tests `== true`
(`ItemDefs.slotsFor`, `RifleGrant`, both `RobuxShop`s, `BoatPaint`, `PaintServer`, `BoatModules`), verified
by grep. An `~= nil` test anywhere would have silently flipped to "owns everything".

**This fixes the same hole for the M16 at the same time**, which is the honest way round — it was always
there; the Bazooka just makes it cost 80 R$ instead of 30.

### Raised and deliberately NOT fixed (owner scoped this job)

- **finding 0032 (high, new)** — `Q` permanently deletes a paid weapon. `drop` refuses only the Axe, and
  `Granted_<key>` means it cannot come back that run.
- **finding 0017 (high, updated)** — rejoining the same run loses the weapon *and* the already-spent
  charge. Now costs 80 R$ rather than 30.
- **finding 0033 (low, new)** — damage numbers are culled at 260 studs; this weapon reaches 300.

---

## 4. Design decisions that are not obvious

**The 4-second flight is authored, not simulated.** A real ballistic 4-second projectile under Roblox
gravity peaks **392 studs** above the midpoint — off the top of the screen and invisible for most of its
flight. The requirement *"flies in a curve, up and then down"* is a readability requirement, not a physics
one, so the path is a parabola whose height is chosen to stay on camera: `clamp(distance × 0.30, 10, 95)`.

**One `Vector3`, three consumers.** The preview ring, the flight and the blast all come from
`ReplicatedStorage/Combat/Ballistics.luau`, and `Rocket.launch` passes the *same variable* to the client
broadcast and to the delayed blast. The marker cannot disagree with the explosion because they are not two
computations of the same thing — measured at **0.000 studs apart** in Play.

**The server resolves the impact; the client only previews it.** The client says where it was pointing —
which it could already do through `FireWeapon` — and the server re-derives the landing point from the
shooter's own muzzle, capped at `range`. No new trust is granted.

**The impact ray differs from every other ray in the game in two ways, both deliberate.** `IgnoreWater =
false`, because a rocket should throw a plume off the river rather than fly through to the riverbed (and
because with water ignored, aiming at the channel returns *nothing* and the "ground" ring floats in the
sky); and `Workspace.Foliage` excluded, per the reviewer's finding above.

**The marked point is where it lands, full stop.** Nothing intercepts the rocket mid-arc. A rocket that
clipped a branch at the top of its lob and detonated early would make the marker a lie, and the marker is
the whole contract.

**The ring is also the reload indicator.** A five-second wait with no on-screen change is indistinguishable
from a broken weapon, so the ring fades from grey back to red across the reload — telling you both *that*
you are reloading and *how far in*.

**No tracer for a projectile weapon.** A tracer is a hitscan idea. Drawing a beam to the landing spot four
seconds early would spoil the arc, tell every other player exactly where it is going, and in first person
put a 300-stud Neon slab through the camera — the "big yellow square" bug this file was fixed for in #117.

**`cooldown`, not `fireInterval`; `blastDamage`, not `damage`.** Both fields are deliberately *absent* from
`ItemDefs.Bazooka` so that the two most likely future mistakes fail cheaply instead of silently. See §1.1
and the `SkillDefs` note.

---

## 5. Balance

```
Bazooka   300 at centre · 30-stud radius · 4 s flight · 5 s reload · 300 studs · 6 rockets a run
```

| Weapon | Damage | Cycle | Range | Ammo |
|---|---|---|---|---|
| Pistol | 20 | 0.22 s | 220 | loot + Salvage |
| M16 | 14 × 20 | 2.00 s | 250 | **Robux only — 30 bursts/run** |
| Shotgun | 24 × 6 | 0.70 s | 95 | loot + Salvage |
| **Bazooka** | **300 in a 30-stud radius** | **5.00 s** | **300** | **Robux only — 6 rockets/run** |
| Turret | 75 | 0.30 s | 350 | boat cargo, gunner seat only |

Against live HP — Piranha 15, Crocodile 40, Boar 50, Wolf/Bandit 55, RiverHippo 120, Generator 150 — **one
rocket kills every one of them anywhere in the radius**, including at the 25 % rim (75 still kills
everything but the hippo and the generator).

⚠️ **This is the THIRD `power = true` item**, and `GAME.md` said in writing that the M16 was "not a licence
for a third". It is recorded as a decision rather than folded in — see `GAME.md` and `MonetizationDefs`.
Unlike the M16 it pays two costs the crew can see (a telegraphed 4 s flight and the longest reload in the
game), but that is **not** the Armored Boat's crew-wide argument. What holds the line is unchanged: **6
rockets a run with no way to get more**. If it plays badly the lever is `ammoOnLoot`, not `blastDamage`.

**Noted, not acted on:** owning both paid weapons fills a base loadout (Axe + Torch + M16 + Bazooka = 4 of
4), so camp weapon crates start being refused. Only affects someone who owns both passes. The Extra Slots
pass "solves" it, which is an uncomfortable answer and should not become the official one.

---

## 6. Verified in Play (GROUND-RULES §7)

Driven end-to-end over Studio MCP. Every check states what failure would have looked like.

| # | Check | Result |
|---|---|---|
| 1 | **Flight time**, launch→impact timestamped on the server | **4.017 s** and **4.016 s** on two shots ✅ |
| 2 | 🔴 **The reload survives `SkillGun = 10`** — 70 trigger pulls over 7 s, straight through the 3.503 s mark the old rule would have allowed | **exactly 2 rockets, 5.100 s apart** ✅ |
| 3 | **One round per pull** | 70 pulls → ammo 30 → 29 → 28 ✅ |
| 4 | **Blast falloff**, read from the server's own per-target log | 8.5 st ×1.00 · 12.5 ×1.00 · 16.7 ×0.91 · 19.1 ×0.79 · 20.3 ×0.74 · 23.0 ×0.60 — matches the formula to 3 dp ✅ |
| 5 | **Falloff at its boundaries** (0 / 14.9 / 15 / 22.5 / 30 / 30.1 / 100 studs) | 1.00 · 1.00 · 1.00 · 0.625 · 0.25 · **0** · **0** ✅ |
| 6 | **Damage at full factor** | ×1.00 → exactly **300** ✅ |
| 7 | 🔴 **Players take zero damage** — rocket detonated at the player's own feet, with a tagged witness 3 studs away | witness **−300**, player **100 HP / Humanoid 100.0 / not Downed** ✅ |
| 8 | 🔴 **The boat takes zero damage** — blast landed 3.3 studs from the hull, witness placed on the deck | witness **−300**, boat **100/100, 86 parts intact** ✅ |
| 9 | **Range clamp** — aim 800 studs out | impact at **300.2 studs** ✅ |
| 10 | **Aim straight up at the sky** | dropped to the **ground 5 studs away**, not an air burst 300 studs overhead ✅ |
| 11 | **Aim at the river** | resolved on the **water surface (y = 12)**, not 1000 studs into the sky ✅ |
| 12 | **Determinism** — the preview and the launch must agree | identical to < 0.001 studs; two live shots landed **0.011 studs apart** ✅ |
| 13 | 🔴 **The rocket lands on the marker** | marker measured **0.000 studs** from the blast point, at the true 30-stud radius ✅ |
| 14 | 🔴 **It really arcs** — rocket Y sampled against the straight line over a whole flight | +2.8 → peak **+9.9 at t=2.17** (arc setting 10.0, apex due at 2.00) → +0.8 at impact ✅ |
| 15 | **Held art** | a real **MeshPart, 6.50 studs**, not the greybox box; hotbar slot shows the bazooka glyph + rocket count ✅ |
| 16 | **Projectile art** | real **MeshPart, 4.00 studs**, with trail, `rocket_loop` and `rocket_whistle` both playing on it ✅ |
| 17 | **Preview ring** | radius 30 = the real blast radius, `CanQuery = false`, rim adornment present ✅ |
| 18 | 🔴 **Blast FX survive a non-rendering client** | `Blast`, `Shockwave`, `BlastFx` all created with `RenderStepped = 0/s` ✅ |
| 19 | **Lifetime pass grant** (the user really owns `1956512376`) | `[RifleGrant] johnygorsky10 -> Bazooka (lifetime pass)` on join, unaided ✅ |
| 20 | 🔴 **The money bug** — shop row with ownership unresolved | **`CHECKING`**, button disabled ✅ |
| 21 | …then resolved as **not owned** | **`R$ 80`**, live ✅ |
| 22 | …and for an owner | **`OWNED`** ✅ (and `Lifetime Bazooka` correctly stays buyable — Roblox itself refuses a duplicate pass purchase) |
| 23 | **Startup consistency check** | "Bazooka (one run) advertises 6, `ItemDefs.Bazooka` grants 6 — MATCH" ✅ |
| 24 | **Analyzer**, game tree | clean. The only two lobby-tree messages are pre-existing files this job never touched (`PilotIdle`, the dead `lobby/sync/ServerStorage` fork) ✅ |
| 25 | **No test residue** | every dummy, folder, log and attribute removed; `SkillGun` restored from 10 to 0; Edit datamodel clean ✅ |

### Corrected mid-verification

- A first falloff run reported wild numbers (`572`, `600`, `402` against an expected 300). **The user was
  playing in the same session and firing their own rockets** — ammo went 6→0 from one scripted shot. Job
  #117's summary records the identical confusion. Re-run against the server's own per-target log lines,
  which carry their own distance and factor and so cannot be attributed to the wrong blast.
- A first boat test reported "no blast on the boat" **and correctly refused to claim a pass** — the shot
  had hit the riverbank 46 studs short, which is right (you cannot shell through a bank). Re-run by
  searching for an aim point that actually resolves within 30 studs of the hull.

### Not verified, and why

- **A real Robux purchase.** `MarketplaceService` prompts do not complete in Studio and
  `Profiles.recordPurchase` refuses without `isPersisting`. The grant *mechanism* is exercised (checks
  19–23) and the lifetime path ran for real; the `ProcessReceipt` branch for the 80 R$ product has not.
  **Needs one purchase on the published place** — the same item Job #117 left open.
- **A second player seeing the rocket and marker.** Solo Studio session. The mechanism is a
  `FireAllClients` broadcast that every client renders identically, and the marker was confirmed on the
  shooter's client, but two clients were not observed at once.
- **A screenshot of the arc in flight.** `screen_capture` timed out repeatedly because the Studio window
  kept losing rendering (§2). The arc is verified numerically instead (check 14), which is stronger than a
  still frame, but nobody has photographed it.
- **Mobile.** `TouchFire` is unchanged so no new touch surface was added, and the aim ring deliberately
  samples the **reticle** on touch rather than the finger — but this has not been measured in the Device
  Emulator, and this job *does* add persistent world-space furniture, so #117's exemption no longer fully
  applies.

---

## 7. Files

### Both trees, edited identically (`diff` silent — verified)
- `ReplicatedStorage/Progression/MonetizationDefs.luau` — the pass + the `RunGrants` row; header now says three
- `ReplicatedStorage/Progression/ProfileConfig.luau` — `RUN_GRANT_KEYS` gains `"bazooka"`
- `ReplicatedStorage/Progression/SkillDefs.luau` — the Gun Discipline exemption now covers both paid weapons
- `ReplicatedStorage/UI/Theme.luau` — `icon.bazooka` / `icon.rocketAmmo`, `itemIcon.Bazooka`, both `productFallbackIcon` rows
- `ServerScriptService/Progression/MonetizationServer.server.luau` — publish ownership either way + `PassesChecked`

### Both trees, same insertion applied separately (pre-existing divergence preserved)
- `StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` — the `CHECKING` state
- `ServerScriptService/Progression/AdminServer.server.luau` — `bazookaCharge` (both), `bazooka` (game only)
- `StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` — the rows

### Game tree only
- `ReplicatedStorage/Combat/Ballistics.luau` **(new)** — arc, impact resolution, falloff, muzzle
- `ReplicatedStorage/Combat/GroundRing.luau` **(new)** — the ring, shared by the preview and the marker
- `ServerScriptService/Combat/Rocket.luau` **(new)** — launch broadcast + the blast
- `StarterPlayer/StarterPlayerScripts/Combat/RocketFx.local.luau` **(new)** — flight, marker, explosion
- `ReplicatedStorage/Inventory/ItemDefs.luau` — the `Bazooka` entry + the projectile fields on `ItemDef`
- `ServerStorage/Inventory/WeaponAssets.luau` — `ART.Bazooka` + the new `ROCKET` table
- `ServerScriptService/Combat/WeaponServer.server.luau` — the projectile branch, `burstUntil` → `lockUntil`, `cueRandom`
- `StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau` — no tracer for projectiles, the reload lock, the aim ring, `muzzleWorld` delegated to `Ballistics`
- `ServerStorage/Inventory/InventoryService.luau` — startup warn when a weapon's art is missing or still wrapped

### Docs
`ASSETS.md` (§3.2 audio, §5.1 monetization rows, new §5.2d) · `GAME.md` (the table + the third exception) ·
`findings/0032`, `findings/0033` (new) · `findings/0017` (updated)

### Not touched, and that is the point
`ShopDefs.luau`, `ExcursionServer.server.luau`, `InventoryHud.local.luau`, `TouchFire.luau`,
`PlayerCombat.server.luau`, `CombatFx.luau`, `Profiles.luau`, `RifleGrant.server.luau`.
**`RifleGrant` and both shops needed no change at all** — Job #117's `RunGrants` really was generic, which
is the cleanest evidence that the abstraction was worth building.

### Studio (not Rojo-synced — 🔴 SAVE THE PLACE)
`ServerStorage.AssetLibrary.Weapons.Bazooka` and `.Rocket` — Meshy `Model` wrappers **deleted**, both now
bare MeshParts matching the other guns. Both scanned: **0 scripts**.

---

## 8. Left for the owner

1. 🔴 **Save the GAME place**, or both weapon meshes revert to Model wrappers and the Bazooka draws a grey
   box. `InventoryService` will warn loudly at startup if that happens.
2. **One 80 R$ purchase on the published place** to exercise `ProcessReceipt` for real (§6).
3. **The pass badge**, if it bothers you: a transparent (RGBA) re-upload of `RobloxPassBazooka.png` plus a
   `Theme.productIcon.bazookaLifetime` entry. Until then the lifetime row shows the launcher glyph and the
   one-run row shows a missile — which is legible and arguably clearer.
4. **Findings 0032 / 0017** are both high-severity money paths, still open by your call.
5. **Mobile**, when you are willing to hand over Studio for the Device Emulator.
