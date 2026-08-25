# Job #118 — Implementation plan

**Project**: `roblox.jungle` · **Created**: 2026-08-25 · **Status**: awaiting agreement
**Reviewer**: an independent agent is running against the requirement (GROUND-RULES §8). This plan will
be revised against what it finds before any code is written — see §0c.

---

## 0. What is already true (verified, not assumed)

| Claim | How it was verified |
|---|---|
| The Bazooka's Hub ids exist and are **live and wired to nothing** | `ASSETS.md:861-862`, `MonetizationDefs:55` note. Pass `1956512376` (250 R$), product `3709767468` (80 R$) |
| All 9 new asset ids are real, mine, and the right type | Studio `GetProductInfo` on each: 6 × AssetTypeId 3 (Audio), 3 × 1 (Image), 2 × 10 (Model), creator `johnygorsky10` |
| The clip lengths | `Sound.TimeLength` read live in Studio after `IsLoaded` — see §5. **Not** inferred from filenames (the M16's 3.888 s clip is why) |
| Both meshes are barrel/nose along **+X**, +Y up | `AssetService:CreateEditableMeshAsync` vertex profile (3 859 / 14 216 verts, 12 slices) **and** a rendered side-on capture with axis markers. The Bazooka's grip hangs −Y at the −X end and the tube opens at +X; the Rocket's fins are at −X and the nose at +X |
| Both AssetLibrary entries are **Model wrappers**, so the inventory cannot see them | `inspect_instance` → `Weapons.Bazooka` is a `Model` containing a `MeshPart`. `InventoryService:44-52` only indexes children that `IsA("BasePart")`. Left as-is the Bazooka silently draws the grey greybox box |
| Neither model contains a script | enumerated all descendants: MeshPart + SurfaceAppearance only, ×2 |
| Enemies, camp guards and generators all die by **watching `HP` change** | `EnemyRig:465`, `ExcursionServer:1145`, `Generators:443`. So a blast that writes `HP` needs no new death plumbing |
| The 5 shared files are still **byte-identical** across the two trees | `diff -q` on `MonetizationDefs`, `Theme`, `ProfileConfig`, `MonetizationServer`, `SkillDefs` — all silent |
| `RunGrants` really is generic | `RobuxShop:211` loops it; `RifleGrant:135` loops it. **Neither shop file nor the grant file needs a code change** — the Bazooka is a data row in both |

## 0b. The owner's four decisions (asked 2026-08-25, all four recommendations taken)

1. **Blast damages enemies, camp guards and generators only.** Players, crew and the boat are never hurt.
   `rocket_impact_near` is a *sound* cue for a nearby blast, not a damage event.
2. **Max target distance 300 studs**, clamped along the aim.
3. **6 rockets a run · 300 damage at the centre · 30-stud radius**, falling to 25 % at the rim.
4. **Both markers**: a private aim preview while the weapon is held, and a public marker at the locked
   impact point for the 4 s of flight.

## 0c. What the reviewer changed (GROUND-RULES §8)

One independent agent, given the requirement and the repo and told **nothing** of this plan. It reached
the plan's two load-bearing conclusions on its own (the `fireInterval` trap, and that a server-moved
anchored part must not be used for the projectile) and then found **eight things this plan did not have**.
Each was re-verified in the file before being accepted.

| # | What it found | Verified how | What changed here |
|---|---|---|---|
| 1 | **`damage = 300` is a loaded gun.** `WeaponServer:380` falls through to hitscan `volley()` for any `kind == "Gun"` without a branch. A missed branch ships a **300-damage instant-hit sniper rifle** | read the fall-through | The blast number moves to **`blastDamage`** and `damage` is left **unset**. A missed branch is now a 20-damage pistol shot — a visible nuisance, not a shipped exploit |
| 2 | **Foliage leaves are `CanQuery` and stop rays** (`findings/0023`), and with streaming the client *has not loaded them* while the server has — so a client-side preview and the server's impact point diverge by tens of studs | read the finding; confirmed foliage is one named folder | Both sides exclude **`Workspace.Foliage`** from the impact ray. This also removes the divergence entirely, and it is simply *correct*: a rocket punches through a fern, a bullet does not |
| 3 | **Every new world part must be `CanQuery = false`** or it breaks four unrelated systems: it stops other players' bullets (`WeaponServer:146-153` filters only char+boat), yanks the boat camera in (`BoatCamera:113-122`), makes the aim disc **hit itself and creep toward the camera** (`WeaponClient:60-63`), and reads as ground to the 8-stud "am I aboard" ray (`HudState:159`) | read all four filters | Stated explicitly for every part the feature creates, and called out in the verification table |
| 4 | **`CombatFeedback` culls at 260 studs** but this weapon reaches **300** | `CombatFeedback:38,187` | The blast VFX is its own code (already was) and is not routed through `CombatFx`. Accepted limitation: at >260 studs you see the explosion but no damage numbers |
| 5 | **Enemies are reaped mid-flight.** `CULL_BEHIND = 260` and the boat covers ~208 studs in 4 s, so a target 60 studs behind the boat at launch is gone at impact | `EnemyServer:38,404` | Confirms the "re-scan at impact" rule and adds an explicit `model.Parent ~= nil` re-check |
| 6 | **The rocket's sounds must not live on `HeldItem`** — `updateHeldVisual` destroys and rebuilds it on every equip and respawn, so a whistle parented there dies on a mid-flight slot switch *and* follows the player instead of the rocket | `InventoryService:130-133`, `WeaponServer:64-69` | Already the plan; now stated as a rule |
| 7 | **`rocket_whistle` is 3.840 s against a 4.000 s flight** — 160 ms of silence in the worst possible place, right before impact | arithmetic on the measured length | The whistle starts at **t = 0.16 s**, so it ends *on* the blast. Imperceptible at the launch end, and it removes the gap |
| 8 | **A pass owner can buy a charge that is never spent.** `checkPasses` only ever writes `Owns_<key>` when the answer is **true** — there is no "not owned" and no "check finished" — so both shops show a live buy button for up to 20 s, and `RifleGrant` then prefers the free pass grant and never spends or refunds the charge | `MonetizationServer:114-129`, `RobuxShop:173-177`, `RifleGrant:105-119` | **Fixed in this job** (owner's call) — see §2b |

### Raised, and deliberately NOT fixed here (owner's call, 2026-08-25)

Both are pre-existing, both affect the **M16 today**, and both are now logged as findings rather than
folded into this job's diff:

- **`Q` permanently deletes a paid weapon.** `InventoryService.drop:326-328` refuses only the Axe, and the
  hotbar binds `Q` to drop. One mis-key destroys a 250 R$ purchase, and `RifleGrant`'s `Granted_<key>`
  guard means it cannot come back that run. → **finding**
- **Rejoining the same run loses the weapon and the charge** (`findings/0017`, already open, severity
  high). `InvSeeded` and `Granted_<key>` are per-session player attributes; the profile charge is already
  spent. → the existing finding is updated to record that the Bazooka raises its cost to 80 R$.

### Reviewer claims checked and found not to apply

- *"Reusing `burstDuration` fires 50 rockets"* — true of the obvious implementation, but this plan never
  reused it. Recorded anyway because it is the trap a later reader would fall into.
- *"A radius scan on the `HP` attribute kills the crew and the boat"* — **verified true and important**:
  player HP is a character-**Model** attribute (`PlayerCombat:108`) and so is the boat's
  (`EnemyServer:366`), sharing the name with enemies. This plan's tag-walk cannot reach them, but the
  blast now uses `CollectionService:GetTagged` over the three tags instead (§4.3), which cannot reach a
  player or the boat **by construction** rather than by a filter someone could later drop.
- *"A Roblox `Explosion` instance"* — never considered, and worth recording why it would be the worst
  choice available: enemies here take damage through an `HP` **attribute**, not a `Humanoid`, so an
  `Explosion` would do **zero** damage to every enemy while killing the entire crew.

---

## 1. The shape of the work

This is **two jobs stacked**, and they are very different sizes:

- **The selling half is almost entirely DATA.** Job #117 built `MonetizationDefs.RunGrants`,
  `Profiles.addRunGrant/takeRunGrant/getRunGrant`, the third `ProcessReceipt` route, the shop's
  OWNED / THIS RUN / NEXT RUN row states and `RifleGrant`'s watcher — all of it generic and all of it
  looping the catalog. The Bazooka is **one row in `RunGrants`, one in `GamePasses`, one key in
  `RUN_GRANT_KEYS`, three `Theme` entries** and it is on sale in both shops with correct states.
- **The firing half is genuinely new.** Every weapon in this game is hitscan: a ray, a hit, damage on the
  same frame. This is the first weapon with a **4-second gap between the trigger and the damage**, the
  first with **area damage**, and the first that must be **drawn flying**.

So the plan spends its length on the second half.

---

## 2. Data — the selling half (both trees, edited identically)

### `ReplicatedStorage/Progression/MonetizationDefs.luau`
```lua
MonetizationDefs.RunGrants = {
    { key = "m16", ... },                                    -- unchanged
    { key = "bazooka", productId = 3709767468, robux = 80,
      name = "Bazooka (one run)", itemId = "Bazooka", rounds = 6,
      passKey = "bazookaLifetime",
      blurb = "The Bazooka + 6 rockets, this run only" },
}

MonetizationDefs.GamePasses = {
    ...,
    { key = "bazookaLifetime", gamePassId = 1956512376, robux = 250,
      name = "Lifetime Bazooka", power = true,
      blurb = "Start every run with the Bazooka + 6 rockets" },
}
```
⚠️ The file's header says *"TWO items now carry that flag"*. It becomes **three**, and the header, the
`m16Lifetime` note's closing line (*"Do not quietly add a third"*) and `GAME.md` all have to be updated to
say so out loud rather than letting a third exception look routine. See §9.

### `ReplicatedStorage/Progression/ProfileConfig.luau`
`RUN_GRANT_KEYS = { "m16", "bazooka" }`. Its own comment already says to keep it in step by hand.
No `migrate()` change is needed — `runGrants` is already a table and a missing key reads as 0.

### `ReplicatedStorage/UI/Theme.luau`
```lua
Theme.icon.bazooka    = "rbxassetid://76642882799637"   -- bazooka_icon, 512x512 RGBA
Theme.icon.rocketAmmo = "rbxassetid://100284588876499"  -- missile, 512x512 RGBA
Theme.itemIcon.Bazooka = "bazooka"
Theme.productFallbackIcon.bazookaLifetime = "bazooka"
Theme.productFallbackIcon.bazooka         = "rocketAmmo"
```

🔴 **No `Theme.productIcon` entry for the pass, and that is a decision, not an omission.**
`RobloxPassBazooka.png` → `78985801749301` is **1254×1254 RGB with NO alpha** (read from the PNG's own
IHDR, byte 25 = colour type 2). That is exactly the `RobloxPassM16.png` situation, and Job #117 only got
a round badge for the M16 because the user supplied a *second*, transparent store image. There is no such
image for the Bazooka, so using the Hub art in-game would render a **square inside the round badge**.

Instead the two rows are split by meaning, which also solves the same "two adjacent rows both starting
with *Bazooka*" legibility problem the M16 rows had:

| Row | Glyph | Why |
|---|---|---|
| **Lifetime Bazooka** (250 R$) | `bazooka` — the launcher | you are buying **the weapon**, forever |
| **Bazooka (one run)** (80 R$) | `rocketAmmo` — a single missile | you are buying **one run's rockets** |

`78985801749301` stays recorded in `ASSETS.md` as **Hub listing art only**, with the same do-not-substitute
warning the M16's three ids carry. *If you would rather the pass row show the artwork, the fix is a
transparent re-upload of the same PNG — not a different icon.* Flagged in §11.

## 2b. The one inherited money bug being fixed here (owner's call)

**A Lifetime owner can buy a per-run charge that is never spent and never refunded.**

`MonetizationServer.checkPasses:114-129` waits up to 20 s for the profile, then writes `Owns_<key>`
**only when the answer is true**. There is no "not owned" write and no "the check has finished" signal, so
`RobuxShop:173-177` has no way to tell *"they don't own it"* from *"we don't know yet"* and shows a live
buy button either way — it says so in its own comment. `RifleGrant:105-119` then prefers the free pass
grant and **never spends the charge**, which sits on the profile forever.

Fix, in both trees:
- `checkPasses` writes the result **either way** (`false` as well as `true`) and sets a single
  `PassesChecked` attribute when the whole loop is done. Everything in both trees tests `== true`
  (verified by grep), so publishing `false` changes no existing behaviour.
- The per-run rows hold their button **disabled until `PassesChecked`**, then decide as they do today.

This fixes the same hole for the **M16** at the same time, which is the honest way round: it was always
there, and the Bazooka just makes it cost 80 R$ instead of 30.

### Not touched, and that is the point
`RobuxShop.local.luau` (both trees), `MonetizationServer.server.luau` (both trees),
`Profiles.luau`, `ShopDefs.luau`, `InventoryHud.local.luau`, `TouchFire.luau`.
Each of them already loops a catalog. **If any of these needs an edit, the generic plumbing Job #117
claimed to have built was not actually generic, and that is worth knowing** — it will be checked, not
assumed, and recorded either way in the final summary.

---

## 3. `ItemDefs.Bazooka` — and what makes a weapon a projectile

```lua
Bazooka = {
    name = "Bazooka",
    kind = "Gun",                 -- still a Gun: reticle, TouchFire, hotbar ammo all key off this
    color = Color3.fromRGB(64, 68, 58),
    ammoAttr = "AmmoBazooka",
    -- ⚠️ NO `damage`, AND THAT ABSENCE IS DELIBERATE — see the 🔴 below.
    range = 300,                  -- max target distance; the aim is clamped to it
    pellets = 1,
    spread = 0,
    -- ⚠️ NO `fireInterval` either. See the second 🔴.
    -- projectile fields (Job #118) — PRESENCE of `flightTime` is what makes it a projectile
    flightTime = 4.0,
    cooldown = 5.0,               -- the reload, and the ONLY number that gates it
    blastDamage = 300,            -- at the centre of the blast
    blastRadius = 30,
    blastInner = 0.5,             -- inner half of the radius takes full damage
    blastMinFactor = 0.25,        -- and the rim takes a quarter
    ammoOnLoot = 6,
    -- NO ammoPerCrate, deliberately — same hard cap that holds the M16's line
}
```

🔴 **THE BLAST DAMAGE IS `blastDamage`, NOT `damage`, AND THAT IS A SAFETY CHOICE.**
`WeaponServer:380` falls through to hitscan `volley()` for **any** `kind == "Gun"` that no earlier branch
claimed. Put 300 in `damage` and forget the projectile branch — or move it below the fall-through in a
later edit — and the game ships a **300-damage, 300-stud, instant-hit sniper rifle** that looks exactly
like the weapon working. With `damage` left unset, that same mistake produces `volley`'s default of 20:
still wrong, but obviously and harmlessly wrong. The failure mode is chosen, not left to luck.

🔴 **AND `cooldown`, NOT `fireInterval`, FOR THE REASON THE M16 ALREADY DOCUMENTS.**
`WeaponServer:328` computes `interval = fireInterval * (0.965 ^ SkillGun)`. A `fireInterval` of 5.0 becomes
**3.503 s at `SkillGun = 10`**, so "a hard 5-second reload, identical for every player" would silently
become 3.5 s for anyone with Gun Discipline. It is invisible in exactly the conditions it gets tested in:
Studio dev profiles start empty (`ProfileConfig:24`) and the normal fix for that is the admin panel's
one-click **MAX ALL Skills** — so the tester is *guaranteed* to be in the broken case.

Rather than carry the same number in two fields and let them drift, `fireInterval` is simply **absent**.
The unscaled latch (§4.1) reads `cooldown`; the cheap anti-mash pre-gate falls back to its 0.22 s default,
which is harmless because the latch is checked first and is five seconds long. **One number, one meaning.**

`SkillDefs`' M16 exemption note gains the Bazooka: neither paid weapon is scaled by a paid skill.

---

## 4. Firing — the new work

### 4.1 The lockout: rename `burstUntil` → `lockUntil`

`WeaponServer` already has a weapon-owned, unscaled latch checked before the rate limiter. It is exactly
the right mechanism for a reload; it is only *named* after the M16. Renaming it (one file-local) and
widening its comment is the honest move — leaving a bazooka reload running through something called
`burstUntil` is how the next reader gets this wrong.

```lua
if def.flightTime then
    lockUntil[player] = now + (def.fireInterval or 5)
    Rocket.launch(player, def, itemId, origin, impact)
    return
end
```
Placed **after** the ammo spend, exactly where the burst branch sits, so one trigger pull = one rocket =
one round, and an aborted anything is never refunded (the file's existing rule).

### 4.2 `ReplicatedStorage/Combat/Ballistics.luau` — **new, shared, the single source of the arc**

Server and client must agree on *where the rocket lands* and *what path it takes*, or the preview ring
lies, the rocket lands somewhere other than the marker, or the blast goes off where nothing exploded.
Three functions, one copy, required by both sides:

```lua
Ballistics.resolveImpact(origin, aimPoint, range, ignore) -> Vector3
Ballistics.arcHeightFor(distance)                          -> number
Ballistics.pointAt(origin, impact, arc, alpha)             -> Vector3
```

**`resolveImpact`** — the rule is *"the marked point is where it lands"*:
1. Raycast from `origin` along the aim, capped at `range`. Hit → that is the impact.
2. No hit (aimed at the sky, or past 300 studs) → take the point at exactly `range`, then cast **down**
   to find the ground under it. That is the impact.
3. Nothing below either → the point at `range`, an air burst.

⚠️ **Two things this ray does differently from every other ray in the game, and both are on purpose.**

1. **`IgnoreWater = false`.** A bullet ignores the river (`WeaponClient:62`, and `EnemyServer:262-268`
   documents the same trap); a rocket fired at the river should throw a plume off the surface rather than
   fly through it to the riverbed. Without this, aiming at a crocodile in the channel returns *nothing*
   over deep water, the aim point becomes a spot 1000 studs away in the sky, and the "ground" marker
   floats over the river.
2. 🔴 **`Workspace.Foliage` is excluded.** `findings/0023`: FoliageServer's leaf parts are `CanQuery`, so
   they stop a ray like a wall — *and with streaming the client has not loaded the ferns while the server
   has*, which is exactly how a client preview and a server impact point end up tens of studs apart.
   Excluding one named folder removes that divergence at the root, and it is independently the right
   answer: **a rocket punches through a fern.**

**`pointAt`** — `origin:Lerp(impact, a) + Vector3.new(0, arc * 4 * a * (1 - a), 0)`. A parabola that is
exactly zero at both ends, so the rocket leaves the muzzle and arrives at the marker with no fudge.

**`arcHeightFor`** — `math.clamp(distance * 0.30, 10, 95)`. Tuned on screen, not asserted here: the arc
has to be tall enough to read as a lob and short enough to stay on camera. 300 studs → 90 up.

⚠️ **No `UserInputService` in this module.** It is required on the server, and `GetService` for a
client-only service throws there. The camera/pointer helpers stay in `WeaponClient`.

### 4.3 `ServerScriptService/Combat/Rocket.luau` — **new server module**

`WeaponServer` keeps the trigger; the flight and the blast live here, the way `CombatFx` owns the hit
announcement.

**`Rocket.launch(player, def, itemId, origin, impact)`**
- Fires **one** `RocketLaunched` RemoteEvent to all clients: `(origin, impact, flightTime, arc, radius)`.
  All the client needs to draw the whole 4 s; no per-frame replication of a moving part.
- `task.delay(flightTime, blast)`.

**The blast**, at impact time and re-evaluated then, not at launch:
- 🔴 **`CollectionService:GetTagged` over `Enemy` / `CampGuard` / `Generator`, filtered by distance** —
  the shape `MeleeServer:144-153` already uses. **Not** a radius scan that looks for models carrying an
  `HP` attribute, and this is the single most dangerous thing in the job: **player HP is a
  character-Model attribute** (`PlayerCombat:108`) and **so is the boat's** (`EnemyServer:366`), under the
  exact same name. The obvious implementation kills the whole crew and the hull. Iterating the tags cannot
  reach a player or the boat **by construction**, rather than by a filter a later edit could drop.
- ⚠️ **A Roblox `Explosion` instance is the worst available choice** and is worth recording so nobody
  reaches for it: enemies here take damage through an `HP` **attribute**, not a `Humanoid`, so an
  `Explosion` would deal **zero** damage to every enemy while ragdolling the entire crew.
- Falloff: full damage inside `blastInner × radius`, then linear down to `blastMinFactor` at the rim.
- Write `HP`, call `KillReward.onEnemyDamaged(shooter, ...)`, and **one** `CombatFx.hit` per model —
  never per part. `CombatFx`'s header forbids the per-fragment version and a 30-stud blast over a camp
  would be the worst offender yet.
- 🔴 **Everything is re-checked at impact.** Four seconds is long enough for the target to die, despawn,
  or be destroyed; for the shooter to be downed, killed, or to leave the server. The rocket still lands
  (a fired rocket does not un-fire), but `shooter` is only passed to `KillReward` if the player is still
  in the game, and each model is re-read from the world at blast time rather than captured at launch.
- **No line-of-sight check**, deliberately: camps are open and the radius is 30 studs. Recorded as a
  decision so the first "it killed something through a bunker wall" report has an answer.
- **Nothing here touches a player, a character, or the boat.** That is the owner's decision, and it is
  enforced by the tag walk simply never matching them — not by a "skip players" branch that a later edit
  could drop.

### 4.4 `WeaponClient.local.luau` — the trigger, the ring, and one thing that must NOT happen

- 🔴 **No tracer for a projectile weapon.** `fire()` currently calls `shotFx(aim)`, which draws a muzzle
  flash **and a yellow Neon tracer to the aim point**. On a bazooka that is a laser beam pointing at
  where the rocket is *about* to land, four seconds early — it spoils the arc and it is wrong. Projectile
  weapons get the muzzle flash only (bigger, smokier).
- The client-side lockout generalises from `burstingUntil` to a lock that a projectile weapon also sets,
  so the 5 s reload is silent rather than scolding — the same reasoning the M16's note already records.
- **The private aim ring.** While the Bazooka is the active item and `reticleShown()`, a `RenderStepped`
  loop resolves the impact point through `Ballistics.resolveImpact` (same call the server will make) and
  parks a flat ring on the ground there. It is coloured by state, which makes it the reload indicator too:

  | State | Ring |
  |---|---|
  | ready | **red**, solid |
  | reloading | **grey**, and it fills back to red over the 5 s |
  | out of rockets / hands full | hidden (the reticle already says why) |

  One raycast a frame; it lives and dies with the equip, and it is a local part so it costs no
  replication and no other player sees it.

### 4.5 `StarterPlayerScripts/Combat/RocketFx.local.luau` — **new client script**

Purely a listener on `RocketLaunched`; it knows nothing about aiming.

- **The rocket.** Cloned from a copy of the Rocket mesh that the server publishes into
  `ReplicatedStorage` at startup (§6) — clients cannot read `ServerStorage`. Missing → a plain tapered
  part, so it degrades rather than disappears (the `WeaponAssets` rule).
- Moved every `RenderStepped` along `Ballistics.pointAt`, oriented down the tangent (`CFrame.lookAt`
  toward the next sample) so it noses over at the top of the arc. Smoke `Trail` + a `ParticleEmitter`
  so the arc reads from across the river.
- 🔴 **Hidden while it is inside the viewer's own camera.** At `alpha = 0` the rocket is at the muzzle,
  which in first person is *at the eye* — the same geometry-enclosing-the-camera bug that produced Job
  #117's "big yellow square", and a 4-stud rocket would be far worse than a tracer. Because this part is
  **client-local**, each viewer can simply hide their own copy within ~4 studs of their own camera, which
  is exact and costs nothing.
- **The public marker**: the same flat ring at the locked impact point, pulsing for the 4 s, sized to the
  **real blast radius** so "clear out" is an honest instruction. Everyone sees it.
- **At impact**: destroy the rocket, then the blast — particle burst, an expanding + fading shockwave
  ring, a brief `PointLight`, and the impact sound (§5). Under the `jungle-style` skill's rules; mobile
  particle counts kept modest.

⚠️ **Instance Streaming is a reason to draw this client-side, not a problem with it.** A rocket 300 studs
out can leave the client's streamed region; a server part would pop, a locally-created one cannot.

### 4.6 Ring geometry
First choice is a `CylinderHandleAdornment` (it has a real `InnerRadius`, so it is a true annulus with no
texture asset and no z-fighting) laid flat on an invisible anchored adornee. Fallback is a thin
`PartType.Cylinder` disc. **Settled on screen during implementation, not from this document.**

---

## 5. Audio — measured, then assigned

| Clip | Id | **Measured** | Where it plays |
|---|---|---|---|
| `bazooka_shoot` | `135920240434402` | **5.094 s** | fire variant A — on `HeldItem`, spatial |
| `bazoka_shoot` | `122026452986070` | **1.440 s** | fire variant B — on `HeldItem`, spatial |
| `rocket_whistle` | `138261119768443` | **3.840 s** | on the rocket, once at launch |
| `rocket_loop` | `73214531471418` | **1.848 s** | on the rocket, `Looped` |
| `rocket_impact` | `73027674412530` | **2.112 s** | at the impact point, spatial — the distant blast |
| `rocket_impact_near` | `108549200090609` | **4.776 s** | **2D on the client** — the blast that went off next to you |

- **Two fire variants, chosen at random per shot.** Both are attached automatically:
  `InventoryService:235` loops every entry in `art.sound`, so `fire` and `fire2` both land on the held
  part with no new wiring. `WeaponServer` gains a `cueRandom(player, {"fire", "fire2"})`.
- ⚠️ **The two variants are 3.5× different in length** (5.094 s vs 1.440 s), which is unusual enough to be
  worth stating: variant A runs almost the whole 5 s reload. It is a one-shot restarted per shot, never
  layered, so it cannot stack — but if the long tail turns out to muddy the whistle, the lever is trimming
  A's volume, not swapping the clip.
- **`rocket_whistle` is 3.840 s against a 4.000 s flight** — it very nearly *is* the flight, which is
  presumably why it was chosen. But 4.000 − 3.840 leaves **160 ms of silence in the worst possible place:
  immediately before impact.** So it starts at **t = 0.16 s**, not t = 0, and ends *on* the blast. At the
  launch end 160 ms is inaudible under the fire clip; at the impact end it is the difference between the
  whistle running into the explosion and the explosion arriving out of silence.
- **`rocket_impact_near` is 4.776 s against a 5 s reload.** A player firing on cooldown at their own feet
  would keep it almost continuously playing, and six of them would stack it five deep — the cicada failure
  `GameSoundscape:22-31` documents. The near cue is therefore **debounced per client**.
- **`rocket_loop` is 1.848 s over a 4 s flight** = 2.16 iterations, so there is an audible seam at 1.85 s
  and 3.70 s unless the clip happens to be seam-matched. Cannot be determined by reading; **checked by
  ear** during verification, and the lever if it is bad is a short fade rather than a different clip.
- ⚠️ **The two fire variants are two separate `Sound` instances**, because `InventoryService:235` attaches
  one per key and `WeaponServer.cue` looks them up **by name**. So `stopCue(player, "fire")` copied from
  the M16 path would stop the wrong variant half the time. The Bazooka's fire cues are one-shots and are
  never stopped, so this does not arise — recorded because it is not obvious.
- **Near vs far is a distance test on each client**, and they are deliberately different *kinds* of sound:
  far is a spatial `Sound` at the impact point; **near is 2D**, because "the blast went off on top of me"
  is a subjective, concussive cue and a 3D sound at 5 studs does not read that way. Threshold ~60 studs,
  tuned by ear. Every client decides for itself, so six players hear the same explosion correctly from
  six positions.
- ⚠️ **`rocket_impact_near` plays on proximity, not on damage.** Nothing can hurt a player here (§0b.1).

---

## 6. Art and the Studio-side work (🔴 not Rojo-synced)

| # | Change | Why |
|---|---|---|
| 1 | **Unwrap** `AssetLibrary.Weapons.Bazooka`: the `MeshPart` becomes the direct child of `Weapons`, the `Model` wrapper is deleted | `InventoryService:44-52` only indexes `BasePart` children. As imported, the Bazooka would silently draw the grey greybox box and look like the code was never written |
| 2 | Same for `AssetLibrary.Weapons.Rocket` | the launch code looks it up by name in the same table |
| 3 | `CollisionFidelity = Box`, `RenderFidelity = Automatic` on both | matches the other three guns, and the memory note that Meshy imports default to Box collision does not apply to a held/flying part |
| 4 | Server publishes a clone of `Rocket` into `ReplicatedStorage.CombatArt` at startup | clients cannot read `ServerStorage`, and the projectile is drawn client-side |
| 5 | Scan both for scripts before use | already done: **0 scripts**, MeshPart + SurfaceAppearance only |

`WeaponAssets.ART.Bazooka` gets `model = "Bazooka"`, `holdInChar = BARREL_FORWARD` (the measurement in §0
confirms +X forward, +Y up — asserted for *this* mesh, not inherited), a `scale` putting it at ~6.5 studs
held (longer than the M16's 5.00, which is right), a `gripOffset` at the pistol grip, and the four sounds.
**Both numbers are tuned on screen in Play and the final values recorded — not shipped from this plan.**

🔴 **The user must SAVE THE GAME PLACE** or items 1–3 are lost, exactly as Job #117 ended.

---

## 7. Admin

`AdminServer` gains `bazooka` (grant the weapon + rockets now — game tree only, like `m16`) and
`bazookaCharge` (bank a per-run charge as an 80 R$ receipt would — **both trees**, because banking in the
lobby and then launching is precisely the path that cannot otherwise be tested). `AdminClient` gains the
two rows. The two files are already deliberately diverged between trees; each is edited in place and
neither is copied over the other.

⚠️ `RifleGrant`'s **startup consistency check already covers this for free**: it warns if a `RunGrants`
row's advertised `rounds` disagrees with the `ItemDefs` `ammoOnLoot` that is actually granted. If the shop
ever says 6 and the code gives 30, it says so at startup. Its filename stays `RifleGrant` — renaming a
two-way-synced script file risks deleting the source, and its header already describes itself as *"the ONE
place a Robux-bought weapon enters a loadout"*. The header gets the Bazooka added; the name gets a note.

---

## 8. Balance

```
Bazooka   300 dmg at centre · 30-stud radius · 4 s flight · 5 s reload · 300 studs · 6 rockets a run
```

| Weapon | Damage | Cycle | Range | Ammo |
|---|---|---|---|---|
| Pistol | 20 | 0.22 s | 220 | loot + Salvage |
| M16 | 14 × 20 | 2.00 s | 250 | **Robux only — 30 bursts/run** |
| Shotgun | 24 × 6 | 0.70 s | 95 | loot + Salvage |
| **Bazooka** | **300 in a 30-stud radius** | **5.00 s** | **300** | **Robux only — 6 rockets/run** |
| Turret | 75 | 0.30 s | 350 | boat cargo, gunner seat only |

Against live HP: Piranha 15, Crocodile 40, Boar 50, Wolf/Bandit 55, RiverHippo 120, Generator 150. **One
rocket kills every one of them outright anywhere in the radius**, including at the 25 % rim (75 damage
still kills everything but the hippo and the generator).

⚠️ **This is the THIRD `power = true` item, and the second one that did not earn it the way the boat did.**
The Armored Boat's exemption rests on the buff being crew-wide. The M16's did not, and `GAME.md` records
that the owner shipped it anyway and that it is *"not a licence for a third"*. This is that third. What
holds the line is unchanged and it is the only thing that does: **6 rockets a run, no camp crate, no
trading-post row, no `ammoPerCrate`** — plus two costs the M16 does not pay: a **4-second flight** that
telegraphs itself with a marker everyone can see, and a **5-second reload**. If it plays badly the lever is
`ammoOnLoot`, not `damage`.

---

## 9. Docs

- `ASSETS.md` — the 9 new ids in §3.2/§5.1, the Bazooka's ⛔ rows flipped to ✅ wired, the
  do-not-substitute warning on `78985801749301` (Hub art, no alpha), the two glyphs, both meshes.
- `GAME.md` — the "what we actually sell" table gains two rows, and the §"second `power = true`" section
  becomes a third entry rather than being quietly widened.
- `.claude/skills/jungle-style/SKILL.md` — only if the blast VFX establish a reusable rule.

---

## 10. How this gets verified (GROUND-RULES §7 — in PLAY, at the player's camera)

Every check states what **failure** would have looked like, or it is not a check.

| # | Check | What failure looks like |
|---|---|---|
| 1 | Fire once: exactly one rocket, exactly one round spent | ammo drops 2, or 0 |
| 2 | **Flight time**, timestamped launch → blast | anything but 4.0 s ± a frame |
| 3 | **It lands on the marker.** Distance from the blast to the marked point | > 1 stud means the shared `Ballistics` is not actually shared |
| 4 | 🔴 **The reload survives `SkillGun = 10`** — mash the trigger across the 3.50 s mark | a second rocket before 5.0 s (the exact defect the M16 shipped a plan for) |
| 5 | **300 studs is enforced**: aim at something 500 studs away | impact past 300 studs along the aim |
| 6 | **Aim at the sky** | rocket flies off forever, or explodes in mid-air over the shooter |
| 7 | **Blast damage + falloff**: targets at the centre, at half radius and at the rim | not 300 / 300 / 75 |
| 8 | **Nothing outside 30 studs is touched** | a kill at 35 studs |
| 9 | 🔴 **Players, crew and the boat take zero damage** — stand in the blast, park the boat in it | any HP loss at all |
| 10 | **One damage number per enemy**, not per part | a camp lit up with a dozen stacked numbers |
| 11 | **The 4-second window**: kill the target mid-flight; switch weapons mid-flight; die mid-flight | an error, or a blast that does not happen |
| 12 | **First person**: fire and watch the muzzle | the rocket fills the screen for a frame (the Job #117 bug class) |
| 13 | **A second player sees** the rocket, the public marker and the blast | any of them local-only |
| 14 | **Audio**: both fire variants occur over ~10 shots; whistle + loop travel with the rocket; near vs far picks correctly at 20 studs and at 200 | one variant never plays; the loop stays at the muzzle; the wrong impact clip |
| 15 | **Lifetime pass grant** on join (the user owns `1956512376`) | empty loadout, or no rockets |
| 16 | 🔴 **Double-grant trap**: re-set `Owns_bazookaLifetime`, as a mid-run purchase does | **12 rockets instead of 6** — the exact bug `Granted_<key>` was added for |
| 17 | **Per-run charge** in the game place: banked → consumed → `RunGrant_bazooka` back to 0 | double-spendable |
| 18 | **Per-run charge** in the lobby: banked → stays at 1 | consumed by nothing |
| 19 | **All four shop row states** in both shops: `OWNED` / `THIS RUN` / `NEXT RUN` / live price | a live buy button for someone who owns the pass |
| 20 | **Hotbar**: bazooka glyph + rocket count; held item is a real MeshPart | the grey greybox box = the unwrap in §6 was lost |
| 21 | **Startup consistency check** prints nothing | the shop advertises 6 and the code grants something else |
| 22 | **Analyzer clean, both trees**, proven able to fail on a deliberately broken copy | — |
| 23 | **No test residue** in the saved place | — |

**Cannot be verified in Studio, and will be said so plainly**: a real Robux purchase.
`MarketplaceService` prompts never complete in Studio and `Profiles.recordPurchase` refuses without
`isPersisting`. The grant *mechanism* is exercised through the admin actions; the `ProcessReceipt` branch
needs one real 80 R$ purchase on the published place — the same open item Job #117 left.

**Mobile**: no new touch surface is added (`TouchFire` is one-tap-one-rocket and is not changed), but the
ground ring is new on-screen furniture. Per GROUND-RULES §2 I will **ask** before switching your Studio to
the Device Emulator, and say what I need to measure.

---

## 10b. 🔴 Every part this feature creates

`Anchored = true`, `CanCollide = false`, **`CanQuery = false`**, `CanTouch = false`, `CastShadow = false`
— the rocket, its trail holder, the aim ring, the public marker, the shockwave, the light holder.

`CanQuery` is the one that matters and it is not a tidiness rule. A queryable part here breaks **four
unrelated systems**, none of which would be suspected: it stops other players' bullets (`WeaponServer`
filters only the shooter's character and the boat), yanks the boat camera forward (`BoatCamera:113-122`
excludes only the boat and your own character), makes the **aim ring hit itself** so the preview creeps
toward the camera (`WeaponClient:60-63` excludes only the character), and reads as ground to the 8-stud
"am I aboard?" ray (`HudState:159`), flipping the HUD to *ashore* while you stand on deck.

## 12. Findings to log (raised by this job, deliberately not fixed in it)

| Severity | Finding |
|---|---|
| high | **`Q` permanently deletes a paid weapon.** `InventoryService.drop:326-328` refuses only the Axe; `RifleGrant`'s `Granted_<key>` guard means it cannot be re-granted that run. Affects the M16 today and the Bazooka at 250 R$ |
| high | **`findings/0017` updated** — rejoining the same run loses the weapon *and* the already-spent charge. Cost rises from 30 R$ to 80 R$ |
| low | **Damage numbers are invisible past 260 studs** (`CombatFeedback:38`) while the Bazooka reaches 300. The explosion is visible; the numbers are not |
| note | **Generators fall to one rocket.** `Generators.MAX_HP = 150`; 300 at centre and 75 at the rim, so a single rocket kills one out to ~26 studs off-centre. Job #115 tuned them to 10 axe swings. They sit ~200 studs apart, so it is still one rocket each — a consequence, not a bug, but the owner should know |
| note | **Owning both paid weapons fills a base loadout.** Axe + Torch + M16 + Bazooka = 4 of 4 slots, so camp weapon crates start being refused (`InventoryService.grant` returns false). Only affects someone who owns both passes; the Extra Slots pass covers it, which is an uncomfortable answer and should not be the official one |

## 11. Open points for you

1. **The pass badge.** No transparent version of `RobloxPassBazooka.png` exists, so the lifetime row shows
   the **launcher glyph** and the one-run row shows the **missile glyph** (§2). If you would rather the row
   show your artwork, upload a transparent (RGBA) re-export of that same PNG and I will wire it — it is a
   one-line change.
2. **Third `power = true`.** Flagged, not blocked. It will be recorded in `MonetizationDefs` and `GAME.md`
   as a deliberate decision the same way the M16 was, rather than folded in as routine.
3. **Arc height and held scale** are tuned on screen and the settled values recorded; if the lob looks too
   flat or too lofty when you see it, that is one constant.
