# Job #084 — Final summary

**Two playtest rounds on 2026-08-16.** The first pass covered four reported bugs; the second pass fixed
four more (two of them regressions I introduced) and added three features the playtests asked for.
**Job #080 was absorbed into this job** at the user's call and built here.

⚠️ **Status: built and statically verified; the Studio playtest is outstanding.** `tools/luau-analyze.sh`
is clean on the whole GAME tree and every changed script is confirmed synced into the *Last River COOP
Game* place. None of the physics, AI or feel changes can be settled by reading — see **Still to verify**
at the bottom, where item 6 is the critical one.

## What shipped

### 1. The pistol was never broken — carrying disarms you

Confirmed with the user: the gate was `Busy`, set by `ExcursionServer.pickupLoot` while you carry a crate.
All four gates in `WeaponServer.canShoot` behave correctly. The failure was that a refused shot produced
**no output at all** — the reticle *hid itself*, which reads as a UI glitch rather than a rule.

- **`InventoryHud`** — the carry chip now reads **"HANDS FULL — CAN'T FIGHT"** instead of
  "HANDS FULL — CARRYING". The old text restated the crate already visible on the player's head and never
  mentioned the consequence.
- **`WeaponClient`** — the single `localCanShoot()` is split into `seatedAtStation()` / `blockedByCarry()`
  / `reticleShown()`. Seated or unarmed still hides the reticle (the hotbar hides there too, so the whole
  loadout UI goes together); **carrying now shows it in yellow** instead. Yellow outranks the ammo colour,
  so a full magazine can't show red and send the player hunting for ammo they have.
- **`WeaponClient` / `MeleeClient`** — a blocked trigger pull or swing now plays `emptyClick` (already
  debounced 0.3 s) and pulses the reticle, matching the answer the empty-ammo path has given since #075.

**Also fixed while in there:** `WeaponServer` stamped `lastShot[player]` *before* its gates, so a rejected
attempt consumed the rate-limit window and left the player briefly rate-limited after putting the crate
down. Moved after `canShoot`. **Deviation from the plan:** it is stamped *before* the ammo check, not
after both gates as written — the dry-fire click is a real server-side Sound and does need rate limiting.

### 2. The tied boat: an anchor that should never have been there

The report was "riders slide on a tied boat". The cause is worse than the symptom: `DockServer` tied by
setting `hull.Anchored = true`, and `StagingServer`'s header documents that exact anchor→unanchor-with-
riders-aboard transition as the old **"boat disappears"** bug. It was live at all 11+ streamed river docks.

Docks now moor the hull the way the spawn dock has always moored it:

- `SetNetworkOwner(nil)` + a **`LinearVelocity` in `Plane` mode** with a Heartbeat correction loop, eased
  inside 0.3 studs. Hull stays dynamic, so Roblox's native moving-platform carry keeps working — which is
  what stops the sliding, and keeps the project rule against a manual per-frame rider carry intact.
- ⚠️ **Not an AlignPosition**, despite what the approved option said. That wording came from
  `StagingServer`'s *header*, which is stale; the real code at `:141` is a LinearVelocity, and the comment
  above it explains why — plane mode never touches Y, so buoyancy alone owns the float. An AlignPosition
  fights buoyancy on Y and bounces.
- **Moored where it floats, not at the pier.** `TiePrompt` fires anywhere within `REFUEL_RANGE` (65
  studs); holding at the dock centre would reel the boat across the river on one keypress. Freezing the
  current spot is what the anchor did, so tie *feel* is unchanged.
- **The rope got slack (`ROPE_SLACK = 3`).** It was decoration only because anchored parts ignore
  constraints. A dynamic hull makes it load-bearing, and `StagingServer:186` records this exact thing
  going wrong once already — *"the rope was actively harmful (it is what suspended the boat above the
  waterline)"*.
- **`BoatServer` now checks `Tied`** — it never did, because against an anchored hull its forces were
  inert. They are not inert against a hold: a driver holding W would fight it. A tied boat now ignores the
  helm, stops integrating the rudder, and burns no fuel. Buoyancy is computed earlier in the loop, so it
  still floats and bobs.

### 3. Enemies disengage while the boat is tied

Half of this already worked — a tied boat took no hull damage — but the crew standing on deck was still
being bitten and creatures still milled around the hull, which is what read as "they attack even when
tied". In `EnemyServer`:

- `chasing` now requires `not suppressed`, so creatures settle to **idle in view** rather than closing.
- The bite is gated at the call site, so the crew stops being bitten. `applyBite`'s internal tie check is
  gone as a result — replaced by an explicit `canHitBoat` flag (see below).
- Land creatures fall into their existing return-to-anchor branch for free and slink back to the bank.
- Re-aggro is automatic: `chasing` recomputes per frame and `st.roared` resets, so untying replays the roar.
- **Camp guards untouched** — `ExcursionServer`'s `CampGuard`s are a separate system `tickEnemy` never
  drives, and they stand at camps, not docks.

### 4. Sea creatures hunt swimmers

`nearestPlayer` was never the problem (it excludes only `Downed`). The hole was targeting: every sea enemy
chased `hull.Position`, so a swimmer was only ever bitten by standing next to the boat.

- Sea creatures now target the **nearer of {boat, nearest swimmer}**; land creatures stay on the boat
  since they're leashed to a bank anchor and can't cross open water anyway.
- The swimmer list is rebuilt **once per Heartbeat** before the enemy loop, not per enemy — the answer is
  identical for all of up to 10 sea creatures.
- Lead prediction follows the target's own velocity; leading a swimmer on the boat's velocity would aim at
  open water. No `FLANK_DIST` offset against a person — that exists to stop crocs surfacing under the
  hull, and against a swimmer it would make them circle instead of close.
- `CULL_BEHIND` still measures from the boat, so a swimmer heading upstream can't keep creatures alive
  indefinitely behind the run.
- **`applyBite` gained `canHitBoat`.** Without it, a croc that lunged at a swimmer who slipped out of range
  would find no victim and fall through to damaging a hull 200 studs away.

### A3 — the contradiction the two decisions created

Decisions 3 and 4 conflict for a swimmer beside a tied boat. Resolved with one constant rather than left
to emerge in play:

> **`TIED_SAFE_RADIUS = 55`** — while tied, sea creatures neither approach nor bite anything within that
> distance of the hull, boat or swimmer. Outside it, normal targeting resumes.

The dock is genuinely safe; swimming away from it genuinely isn't. This is the lever if docks play too
generous (lower) or the safe zone feels stingy (raise).

---

# Second pass — 2026-08-16 playtest #2

Four issues came back, plus three new asks. **Two of the four were mine**, introduced by the first pass.

### 5. 🔴 The tied boat span and killed the player — MY BUG

`LinearVelocity` applies its force **at its attachment**, and unlike `VectorForce` it has no
`ApplyAtCenterOfMass` (which is exactly why every force in `BoatServer` sets that flag —
`BoatServer:174`). I anchored the moor on `MoorRoot` at the **hull origin** with `MaxForce = 1e6`. On a
lever arm to the real centre of mass that is an enormous torque.

**Why copying StagingServer verbatim was not enough:** it moors a **one-part** boat before modules
exist, so origin and centre of mass coincide and the lever arm is zero. By the first river dock the boat
is **12 parts** — fuel tank, second motor, trailer, searchlight. The console ordering confirms it:
`[Staging] moored boat online` … `[BoatModules] applied` … `Boat -> navy (12 parts)`.

Fixed with a dedicated `DockMoorPoint` attachment placed at `hull.AssemblyCenterOfMass`, re-solved on
every tie (cargo and modules move the centre of mass) and destroyed on untie. Also added a defensive
sweep for an orphaned `DockMoor` — a dock culled and rebuilt while tied would otherwise leave a live
1e6-force constraint fighting the driver forever.

### 6. 🔴 Enemies still vanished instead of dying — the previous fix caused it

The pre-existing fix cleared `state[enemy]` before handing the body to `EnemyRig.die` for its 1.1 s
topple. But `tickEnemy`'s **first guard despawns any enemy with no state entry**, so the corpse was
destroyed on the very next Heartbeat, ~16 ms later. The topple, splash and death sound were all started
on a model that had microseconds to live. A `dying` set now marks the body so the tick leaves it alone
until `EnemyRig.die`'s own callback despawns it.

### 7. The "HANDS FULL" chip sat on top of the health bar

Pre-existing collision, made visible by the new text. `HealthHud`'s holder is anchored bottom-left at
y=0.845 and is 0.042 tall (0.803–0.845); the chip at 0.855 covered 0.819–0.855. Moved to 0.797.

### 8. Hit feedback — Job #080 absorbed and built here

Pulled in at the user's call; #080 is closed and points here.

- **`Combat/CombatFx.luau`** (new, server) — the single seam. Server code calls `CombatFx.hit(pos,
  amount, kind)`; one `RemoteEvent` carries it. `FireAllClients` because the user chose **everyone's
  numbers, weighted equally** — a co-op boat should read as a co-op fight.
- **`Combat/CombatFeedback.local.luau`** (new, client) — impact bursts and floating numbers. **Green**
  for damage dealt, **red** for damage taken. Two fixed pools reused round-robin (20 numbers, 8 bursts),
  one `RenderStepped` driving all of them, and a 260-stud cull — no per-hit allocation, per #080's
  mobile-first constraint. Impacts are particles only: #075's flat Neon slab read as "a white object
  flying past" and #079 removed it.
- **Muzzle flash** in `WeaponClient`, not the feedback file — it has to fire on a **miss** too, and that
  file only ever hears about landed hits.
- **Batched per target, not per pellet.** A shotgun is 6 pellets; `WeaponServer` now sums damage per
  enemy across the volley and reports once. Six players × six pellets would otherwise be 36 remotes and
  36 labels for one volley.
- Hooked at every damage site: `MeleeServer`, `WeaponServer`, `GunServer` (dealt); `EnemyServer` bites
  and `ObstacleServer` (taken).
- **Enemy health bars untouched** — `EnemyHealthBars` already covers both tags and deliberately hides at
  full health.

### 9. Campfire healing (new ask)

**Nothing in the game healed a player.** HP went 100 → 0 across an 18,000-stud run; the only increase
anywhere was the revive at `PlayerCombat:112`, which requires being downed first.

`World/CampfireHeal.server.luau` (new), built on Defender's `AIHealingPad` pattern at the user's
suggestion: a CollectionService tag on each fire's `Core`, a 0.5 s proximity poll (not a Heartbeat —
healing at 60 Hz is indistinguishable from healing at 2 Hz), and a warm particle aura on the character.
Per the user's call it **always heals but trickles under threat**: `4 HP/s` clear, `1 HP/s` while a
living `CampGuard` is within 60 studs. A **downed** player is never healed up — that would delete the
revive mechanic.

### 10. Camp guards re-man by day (new ask)

Guards spawned once and never returned, so a cleared camp stayed cleared. Per the user's call: **day
phase only, one guard at a time**. A per-camp timer only advances while that camp is short-handed, so a
full camp cannot bank credit and dump three guards at once. This also matches `EnemyDefs.strengthFor`,
where land threats already peak by day — and it gives night landings their own distinct shape, since a
cleared camp stays cleared until dawn.

## Files changed

| File | Change |
|---|---|
| `World/DockServer.server.luau` | Anchor → `LinearVelocity` moor + hold loop; rope slack |
| `Boat/BoatServer.server.luau` | Tied boat ignores the helm (required companion) |
| `Enemies/EnemyServer.server.luau` | Swimmer targeting, tied-dock suppression, `canHitBoat` |
| `Combat/WeaponServer.server.luau` | Rate-limit stamped after the gates |
| `Combat/WeaponClient.local.luau` | Split gates; yellow reticle + pulse on a carry-blocked shot |
| `Combat/MeleeClient.local.luau` | Click on a carry-blocked swing |
| `UI/InventoryHud.local.luau` | Carry chip names the consequence; moved clear of the health bar |
| `Combat/CombatFx.luau` | **new** — server seam announcing every landed hit |
| `Combat/CombatFeedback.local.luau` | **new** — pooled impact bursts + floating damage numbers |
| `World/CampfireHeal.server.luau` | **new** — rest at a fire to recover HP |
| `World/Campfire.luau` + `World/CampDefs.luau` | Fire `Core` tagged as a heal source; `HEAL` tuning block |
| `Excursion/ExcursionServer.server.luau` | Day-only, one-at-a-time garrison respawn |
| `Combat/MeleeServer` · `GunServer` · `World/ObstacleServer` | Report hits to `CombatFx` |

## Still to verify (human, in Studio)

Static analysis is clean and the scripts are synced, but none of the following can be read off the code:

1. **Part 2 is the risky one.** Tie with a player on deck → confirm no slide. Then **untie with the crew
   still aboard** — that is the transition `StagingServer` warns explodes, and the whole point of the
   change is that it no longer exists. Watch the bow through several bobs to confirm the rope stays slack.
2. Hold W while tied → the boat must not creep off its berth.
3. Tie at a river dock → creatures stop closing, stay visible, and re-aggro on untie.
4. Swim clear of the boat → you are hunted. Swim beside a **tied** boat → you are not.
5. Part 1 is a read-and-feel check: does the yellow reticle plus the chip actually land at speed?
6. **The spin fix is the critical retest.** Tie at a river dock with modules fitted, untie, and drive
   off — the first pass span the boat because the moor pulled on a lever arm to the centre of mass.
7. Kill an enemy and watch it topple and sink rather than blink out.
8. Damage numbers: green on your hits, red when bitten, one number per shotgun blast per target.
9. Rest at a camp fire: fast when clear, a trickle while a guard lives, nothing while downed.
10. Wait out a day phase near a cleared camp and confirm guards return one at a time, and that none
    return at night.
