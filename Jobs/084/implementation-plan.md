# Implementation Plan — Job #084

**Project**: `roblox.jungle`
**Created**: 2026-08-16
**Status**: Planning — **decisions D1–D4 answered by the user 2026-08-16**; awaiting build go-ahead.

Playtest bugs from 2026-08-16: pistol, tied-boat slide, enemy aggro in water, tied-boat retreat.
Item 5 (hit feedback) stays with **Job #080** and is not built here.

## Approved decisions

| | Decision | Outcome |
|---|---|---|
| **D1** | Item 1 — which gate blocked the pistol | ✅ **`Busy` (carrying loot), confirmed by the user.** Not a firing bug. The ask is now: *tell the player they can't shoot or swing while carrying.* Scope changes from "fix the pistol" to "signal the gate". |
| **D2** | Item 2 — tie method | ✅ **Adopt StagingServer's dynamic hold** instead of `hull.Anchored = true`. ⚠️ See the correction below — the pattern is a **LinearVelocity**, not an AlignPosition. |
| **D3** | Item 3 — retreat while tied | ✅ **Stop approaching, stay visible offshore.** Enemies drop aggro and hold at range; no bites on the crew either. They re-aggro the instant the boat is untied. |
| **D4** | Item 4 — swimmers | ✅ **Sea enemies target the nearest of {boat, swimming player}.** Accepted consequence: swimming stops being a free safe route. |

### ⚠️ Correction to D2 as it was put to you

The option said *"AlignPosition"* because that is what `StagingServer`'s **header comment** says. The
header is **stale**. The code at `StagingServer:141` actually builds a **`LinearVelocity` in `Plane`
mode**, and the comment right above it explains why the header is wrong:

> *"it only controls HORIZONTAL (world X/Z) velocity and NEVER touches Y — so buoyancy alone owns the
> vertical float and the boat bobs exactly like normal (**an AlignPosition would fight buoyancy on Y →
> bounce**)."*

So the plan mirrors the **real** implementation. Building the literal AlignPosition the option named
would reintroduce the exact bounce that comment was written to prevent. Nothing about your decision
changes — the pattern being adopted is the same one, correctly identified.

## Analysis

The intake traced all five items to specific lines and I verified every claim against the code.
**Items 3 and 4 are exactly as written** — no correction needed. Three things the intake did not have:

**1. The client already encodes the reason the pistol won't fire.** `WeaponClient:107` sets
`dot.Visible = localCanShoot()` and `:108` colours it red when out of ammo. So the crosshair *is* a
signal — it just signals by **vanishing**, which reads as "the UI glitched", not "you are holding a
crate". That is why D1 could be answered without a repro session, and it tells us where the fix goes.

**2. `DockServer` does the one thing `StagingServer` documents as broken.** `StagingServer:69-72`:

> *"Moor WITHOUT anchoring. Anchoring an assembly and later unanchoring it while a client-owned player
> stands on it makes the physics explode in one step (the engine then removes the boat) — that was the
> 'boat disappears' bug."*

`DockServer:234` is `hull.Anchored = true` and `:216` is `hull.Anchored = false`, i.e. an
anchor→unanchor transition with riders aboard, at **every one of the 11+ streamed river docks**. The
slide is the visible symptom; the boat-disappears bug is the same transition waiting to happen.

**3. `BoatServer` never checks `Tied`.** It is absent from the `"Tied"` grep entirely. Its Heartbeat
keeps writing `Thrust` and `Current` VectorForces every frame regardless. Against an anchored hull that
was harmless — anchored parts ignore forces. **Against a dynamic hold it is not**: a driver holding W at
a tied pier would fight the hold. This is a *required* companion change to Part 2, not an optional one.

### The rope is about to become load-bearing

`DockServer` builds a visible `RopeConstraint` on tie. On an anchored hull a rope does nothing — anchored
parts ignore constraints, so it has only ever been decoration. **Making the hull dynamic makes that rope
live**, and this codebase has already been burned by precisely that (`StagingServer:186-188`):

> *"the rope was actively harmful (**it is what suspended the boat above the waterline**)"*

`newRope.Length` is currently set to the exact tie-moment distance — i.e. taut on creation. Once the hull
can move, buoyancy bobs it and a taut rope to an attachment 2 studs above the water will haul the bow up.
Part 2 must give the rope slack so it stays decoration. Flagged because it would otherwise look like a
harmless untouched line and reproduce a bug the repo has already paid for once.

---

## Part 1 — Item 1: say that carrying disarms you

Three gates already agree that carrying blocks combat (`WeaponClient:92`, `MeleeClient:20`,
`WeaponServer:54`, `MeleeServer:65`), and `InventoryHud:65-88` already draws a yellow **"HANDS FULL —
CARRYING"** chip while `Busy`. Nothing is broken. What is missing is that the chip states a *state* and
never its *consequence*, and that a blocked trigger pull produces **no response at all**.

No new remote, no new bus. Both changes land where the information already is.

| # | File | Change |
|---|---|---|
| 1.1 | `UI/InventoryHud.local.luau:87` | Chip text `"HANDS FULL — CARRYING"` → **`"HANDS FULL — CAN'T FIGHT"`**. Same length class, same card, same yellow accent — no layout risk. States the consequence. |
| 1.2 | `Combat/WeaponClient.local.luau` | While `Busy`, **keep the reticle visible in yellow** instead of hiding it. A hidden dot explains nothing; a yellow dot is a persistent "this is blocked, and it isn't your input". Split `localCanShoot()` into `hasGun()` / `blockedByCarry()` so the seated cases still hide it (the hotbar hides there too — `InventoryHud:114` — so the two stay consistent). |
| 1.3 | `Combat/WeaponClient.local.luau:111` | In `fire()`, when carry is the blocker, play `UISound.play("emptyClick")` and pulse the reticle — the same on-attempt answer the empty-ammo path already gives at `:115-122`. |
| 1.4 | `Combat/MeleeClient.local.luau` | Same on-attempt click when a swing is refused for `Busy`. No reticle here, so the chip plus the click carries it. |

**Deliberately not done:** hiding or dimming the hotbar while carrying. Equipping is *not* blocked while
`Busy` — only firing and swinging are — so greying the bar would assert something false.

**Server untouched.** `canShoot()` keeps rejecting; this is presentation only.

### One real bug found while reading (in scope, tiny)

`WeaponServer:103-112` writes `lastShot[player] = now` **before** the `canShoot()` and ammo gates. A
rejected attempt therefore consumes the rate-limit window, so a player who taps while carrying is also
briefly rate-limited after they put the crate down. Move the write to after both gates.

## Part 2 — Item 2: tie without anchoring

Mirror `StagingServer:130-175` in `DockServer`'s `tie.Triggered` / `doUntie`.

**On tie** (replacing `hull.Anchored = true`):
- `pcall(hull:SetNetworkOwner(nil))` — server-owned, so the hold loop reads un-lagged position.
- A `LinearVelocity` named `Moor` on a hull attachment: `RelativeTo = World`,
  `VelocityConstraintMode = Plane`, tangent axes world X and Z, `MaxForce = 1e6` (sized to beat the
  constant `Current` force, per `StagingServer:149`). **Y is left free so buoyancy still owns the float.**
- A Heartbeat correction loop driving `PlaneVelocity` toward the moor point, eased inside 0.3 studs —
  copied from `StagingServer:157-174`, disconnecting itself when the constraint is destroyed.

**Moor point = the hull's X/Z at the moment of tying.** Not the pier centre. `TiePrompt` fires anywhere
within `REFUEL_RANGE = 65` studs, so targeting the dock would reel the boat up to 65 studs across the
river on a keypress. Freezing in place is what the anchor did, so tie *feel* does not change.

**On untie:** destroy the `Moor` constraint (and its loop). No anchor transition, matching
`StagingServer:216`'s `hold:Destroy()`.

**The rope:** set `newRope.Length` to the tie distance **+ ~3 studs of slack** so it never goes taut
through the bob, keeping it decoration. See the flagged note above.

**Companion — `BoatServer`:** early in the Heartbeat, when `boat:GetAttribute("Tied")` is true, zero
`thrust.Force` (leave `Current` — the hold's `MaxForce` is explicitly sized to beat it). A tied boat
should ignore the throttle regardless, so this is correct behaviour as well as a physics requirement.

**Why this fixes the slide:** the hull stays a dynamic, server-owned assembly, so Roblox's native
moving-platform carry — the mechanism the project rule says riders must rely on, and which an anchored
part removes — keeps working while moored. No manual per-frame rider carry is added anywhere.

## Part 3 — Item 3: disengage while tied

All in `EnemyServer.tickEnemy` / `applyBite`.

- Read `local tied = boat:GetAttribute("Tied") == true` once per tick.
- `chasing` becomes `dist <= def.aggroRadius and not tied` — this already drives
  `EnemyRig.setMotion`, so creatures visibly settle to idle rather than freezing mid-swim.
- **Sea:** skip the `stepToward` chase while tied. They hold station where they are, in view.
- **Land:** skip the chase branch while tied; the existing `elseif st.anchor` branch then runs and they
  slink back to their bank anchor — already-correct behaviour, reached for free.
- **Bite:** gate the whole `applyBite` call site on `not tied`, so the crew aboard stops being bitten
  (which is the half of item 3 that was broken). `applyBite`'s internal
  `elseif not boat:GetAttribute("Tied")` then becomes dead and is simplified away.
- **Re-aggro is automatic** — `chasing` is recomputed every frame and `st.roared` resets while not
  chasing, so untying replays the aggro roar. Nothing extra needed.

**Camp guards are untouched.** `ExcursionServer`'s `CampGuard`-tagged guards are a separate system that
`tickEnemy` never drives, and they stand at camps, not docks. D3 was about river creatures.

## Part 4 — Item 4: sea enemies hunt swimmers

- Build the swimmer list **once per Heartbeat**, before the enemy loop — not per enemy. Up to 10 sea
  creatures × N players every frame is wasted work, and the list is identical for all of them.
- Detect via `Humanoid:GetState() == Enum.HumanoidStateType.Swimming`, reusing `nearestPlayer`'s existing
  `Downed` exclusion.
- For `category == "sea"`, the target becomes the nearer of the hull and the nearest swimmer.
- **Lead prediction follows the target** — `lead` currently hardcodes `hull.AssemblyLinearVelocity`; a
  swimmer target must lead on the swimmer's own velocity.
- **No flank offset on a swimmer.** `FLANK_DIST` exists to stop crocs surfacing *underneath the hull*;
  against a person it would make them circle instead of attack.
- **Culling stays on the boat.** `CULL_BEHIND` must keep measuring from the hull, or a swimmer heading
  upstream would keep creatures alive indefinitely behind the run.

### A3 — the one interaction D3 and D4 create, and how it is resolved

D3 makes a tied dock safe; D4 makes swimmers huntable. A swimmer next to a tied boat satisfies both, and
they contradict. Resolving it with one tunable rather than leaving it to emerge:

> **`TIED_SAFE_RADIUS = 55`.** While the boat is tied, sea enemies neither approach nor bite **anything**
> inside that radius of the hull — boat or swimmer. Outside it, targeting is normal, swimmers included.

So the dock is a genuine safe zone (D3 honoured), and swimming away from it is still dangerous (D4
honoured). The radius is the single lever if it plays too generous or too tight.

## Verification

No runtime test harness, so per the skill's rule:

1. **`tools/luau-analyze.sh` on every edited `.luau`**, findings resolved before moving on.
2. **Live in Studio** — the physics and AI changes cannot be settled by reading:
   - **Part 2 is the risky one.** Tie with a player standing on deck, confirm no slide; then **untie with
     a player still aboard** — that is the transition `StagingServer` warns explodes, and the whole point
     of the change is that it no longer exists. Watch the bow through several bobs to confirm the rope
     stays slack.
   - Hold W while tied → the boat must not creep.
   - Part 3: tie at a river dock, confirm creatures stop closing, stay visible, and re-aggro on untie.
   - Part 4: swim clear of the boat and confirm you are hunted; swim beside a *tied* boat and confirm you
     are not.
3. **Part 1 is a human check** — a screenshot cannot prove the chip and reticle read correctly at speed,
   and (per the intake) `screen_capture` does not composite BillboardGuis in any case.

## Out of scope

- **Item 5 — hit feedback.** Owned by Job #080. Worth noting that D1 lands next to it: with no muzzle
  flash and no impact effect, a *successful* shot and a *blocked* one look nearly identical, which is
  part of why the pistol read as broken. Part 1 fixes the blocked half; #080 owns the landed half.
- Enemy density, bite damage, and dock spacing — untouched.
