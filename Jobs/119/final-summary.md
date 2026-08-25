# Job #119 — Final summary

**Project**: `roblox.jungle` (GAME place) · **Status**: implemented, verified in Play 2026-08-25, then
six user-reported defects fixed and re-verified the same day

The Rocket Man: an army soldier who stands on the deep camp's watchtower and lobs the Bazooka's rocket at
you every 20 seconds. See [intake.md](intake.md) for the request and the eleven decisions,
[implementation-plan.md](implementation-plan.md) for the agreed approach.

---

## What was built

| Piece | Where |
|---|---|
| `RocketMan` enemy def — 110 HP, 160-stud sight, 4×5.8×3 hitbox, `speed = 0` | `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` |
| Its art/animation/sound table | `sync/ServerScriptService/Enemies/EnemyAssets.luau` |
| `Rocket.launchEnemy` + `enemyBlast` — the enemy-fired shell | `sync/ServerScriptService/Combat/Rocket.luau` |
| Accessory-weld pass (a general rig fix — see below) | `sync/ServerScriptService/Enemies/EnemyRig.luau` |
| `KIND.deep.tower = true`, `CampKind.name`, and the whole `CampDefs.TOWER` tunable block | `sync/ServerScriptService/World/CampDefs.luau` |
| `spawnRocketMan`, `tickRocketMan`, `equipBazooka`, `placeOnPad`, `towerPads`, the `tickGuard` branch, the garrison-count exclusion | `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` |
| `ArmySoldier` rig filed into the library (**place file, not git**) | `ServerStorage.AssetLibrary.Enemies.ArmySoldier` |

**Sync**: every changed file is under `sync/ReplicatedStorage` or `sync/ServerScriptService`, both of which
auto-sync. **No manual Studio copy is needed for the code.** The *asset* half is a place-file edit and needs
you to save (see "What you still have to do").

**Client-side work: none.** The enemy shell is broadcast on the same `RocketLaunched` remote the player's
Bazooka uses, and `RocketFx` is a pure listener — so the red warning ring, the 4-second arc, the whistle,
the shockwave and both impact clips all arrived for free and an incoming shell looks exactly like one of
your own.

## Behaviour as shipped

- **One per landing site**, on the **deep** camp's tower, standing on the `Defender` pad. `KIND.deep.tower`
  turned on to give him a tower; the near camp keeps its now-unmanned one as the arrival landmark.
- **Never moves.** Pinned to the pad, yaws to track you, returns to the pad's own facing when idle.
- **Fires every 20 s** at the nearest live, non-downed player within 160 studs — 300 studs while alerted —
  but never closer than **48 studs** (or he craters his own tower).
- **40 damage** at the centre of a 30-stud blast, falling to **10** at the rim. It hits players, the boat,
  and his own side; it pays the player nothing.
- **Close combat inside 16 studs**: he stops firing entirely and swings on a 1.4 s cycle for 5.53, with two
  alternating animations.
- **No respawn.** Kill him once and the tower is yours for the run.
- **Both towers** carry an `AmmoBox` chest on the `InnerPlace` pad, 45–70 salvage, `Search` prompt.

## Verified in Play — measured, not assumed

Play session on the first landing, camp forced via `ForceFirstCamp`, all numbers read off the live server
or client rather than from the code.

| # | Check | Result |
|---|---|---|
| 1 | Standing on the deck | ✅ ray down from his hitbox hits `RangerTower.Tower."Floor and Roof".Union` 3.91 studs below centre; terrain is **40.2 studs** further down. Visual bottom vs hitbox bottom **delta 0.00** — feet flush |
| 2 | Holds the launcher | ✅ `HeldItem` 6.50 studs, Motor6D `HeldGrip`, muzzle·forward **1.000**, up·worldup **1.000**, on **both** server and client |
| 3 | Fires on the 20 s cycle | ✅ shell landed at t=24.1 s in an 80 s window (20 s cycle + 4 s flight) |
| 4 | Centre damage | ✅ **exactly 40.000** (100→60.0 in one run, 200→160.0 in another) |
| 5 | The ring is escapable | ✅ **survived 50 s at full HP** moving 108 studs every 1.6 s across ~2 shells. Zero damage |
| 6 | Friendly fire | ✅ a guard 14 studs from the impact went **55 → 17.6** |
| 7 | No reward for his kills | ✅ `Salvage 0 → 0` across a shell that damaged a guard |
| 8 | He doesn't shell himself | ✅ `hisHP = 110` untouched after firing; guards at 107/202/219/232 studs also untouched (blast localised) |
| 9 | Close combat | ✅ exact **−5.5296** per swing, 18 swings to down a 100 HP player |
| 10 | Two melee animations | ✅ `567480700` and `567479941` both sampled during the fight, alternating |
| 11 | Does not shell you in melee | ✅ every decrement during the platform fight was 5.5296; no 40-damage hit |
| 12 | Marker pads intangible | ✅ all **4** pads across both towers: `CanCollide=false CanQuery=false CanTouch=false` |
| 13 | Chests on both towers | ✅ two salvage chests at deck height y=55.08, amounts **58** and **45** |
| 14 | Armour survives the rig build | ✅ live rig **86 parts vs library 85** (the extra is the launcher); helmet + vest present; 69 accessory welds logged |
| 15 | Analyzer | ✅ `tools/luau-analyze.sh` — full GAME tree sweep clean |
| 16 | Boat takes the blast | ✅ `[EnemyRocket] BLAST Boat 11.8 studs x1.00 HP 100.0 -> 60.0` → 60→20→0, then `[Boat] DESTROYED — run over`. 40 per shell |
| 17 | **20-second cadence** | ✅ measured off `RocketLaunched` on the client: **+20.0s, +20.0s, +20.0s, +20.0s**, mean **20.0 s** over 4 gaps, every shot `flight=4.0s radius=30` |
| 18 | Falloff curve is right | ✅ a guard at 16.3 studs took `x0.93` — exactly `blastFactor` just outside the 15-stud inner radius |
| 19 | 🔴 Guards still respawn with him alive | ✅ read straight off the garrison loop: `camp (501,1640) alive=0 target=2 timer=5 nextIn=169.77` while he stood 51 studs away at HP 110. **Would have read `alive=1` if the exclusion were missing** |
| 20 | He is not in the garrison list | ✅ `[Garrison] registered near target=1 · deep target=2 · #garrisons=2` — two records, neither his |

## Three more bugs, reported by the user after first playtest, all fixed

Found by the user playing it, which is what a playtest is for. All three were in code this job touched
except the last, which the job's own testing had walked straight past.

### 4. 🔴 "he does not shoot if i am under tower but i was like 20 studs away"

`minFireRange` was **48**, so between `meleeRange` (16) and 48 he did nothing at all — and since he stands
~37 studs up, a player anywhere near the base is inside that band. **Walking up to the tower was a
permanent safe spot**, i.e. the obvious counter-play switched him off instead of escalating him. The worst
possible failure for this enemy.

48 came from "keep the 30-stud crater off his own tower", and the geometry says that reasoning was simply
wrong: at 37 studs up, a shell at the very foot of his tower is already **37 studs** from him — outside the
30-stud radius at *any* horizontal distance. He could never have hit himself. Now **18**, two studs clear of
`meleeRange`, and `Rocket.launchEnemy` is additionally told who fired and skips them — so the number is free
to be chosen for how the fight reads rather than to protect the shooter.
Verified: at the user's exact 20 studs (41.8 studs in 3D) he now fires; before, `41.8 < 48` → silent.

### 5. 🔴 "red circle for shooter is up high it is not on the ground"

The shell was aimed at the target's `HumanoidRootPart` with the target **not** excluded from the ray, so
`resolveImpact` stopped on the player's own body — and the ring is drawn at the impact point, i.e. floating
at chest height with the player standing inside it.

Before/after on the same ray, same spot:

| | Impact landed on | Height above ground |
|---|---|---|
| Before | `johnygorsky10.RainbowHairForRainbowPeopleCortez.Handle` | **4.80 studs** |
| After | `Workspace.Terrain` | **0.00 studs** |

It was stopping on the player's **hair accessory**. Now the aim point is dropped to the surface beneath the
target first, and the target's character joins the tower and the shooter in the ray's ignore list. Live
shells measured `gap = +0.000` against the terrain under them, and the ring reads as a decal on the grass.

⚠️ The player's own Bazooka never hit this, which is why it was not inherited: `WeaponServer` excludes the
SHOOTER, and for the player the shooter is who the ray starts inside. Here shooter and target are different
characters.

### 6. 🔴 "weapon is pointing up??" on the M16 *and* the Bazooka — pre-existing, not from this job

Confirmed not mine first: `InventoryService`, `WeaponAssets`, `ItemDefs` and `WeaponClient` are all
untouched by this job. Then measured — and the first theory was wrong, which is worth recording:

- It is **not** a client/server replication race. Both ends agreed at `dot-forward = +0.476`, **61.5° off**.
- It is a **pose-timing** race. `HeldPose.local.luau` (client) waits `task.wait(0.2)` for the default
  `Animate` script and then plays the carry pose with a **0.15 s fade**. `updateHeldVisual` welds on the
  server the instant the active item changes — well before any of that. The grip is solved correctly *for
  the arm as it is at that moment*, then the carry pose rotates the forearm ~61° and the rigidly welded
  weapon rotates with it.
- A first attempt gated the re-solve on "does the hand look arms-down". Measured: it never fired, because
  the default idle **already** poses the arm, so `handUp·rootUp` was nowhere near the tested 0.9.

Fixed by asking the Animator directly: after welding, wait for the carry-pose track to reach weight > 0.9
**and** the character to be standing still, then re-solve `C0` once. Guarded so it fires at most once and
bails if anything re-equipped meanwhile — a held weapon is *supposed* to swing with the arm, so re-solving
during a walk or a melee swing would bake that pose in permanently.

Verified on the client, which is the only view that matters: Bazooka `+0.9999 / +0.62°`, M16
`+0.9999 / +0.46°`, after a respawn `+1.0000 / -0.04°`, after fast slot-switching `+1.0000 / +0.26°`.

⚠️ **One thing left standing, and it is worth knowing.** The carry pose plays at `AnimationPriority.Idle`,
which is the same priority as the default R15 idle — measured, both at weight 1.00, so they blend **50/50**
and the carry pose is only half applied. That is how Roblox's own `Animate` script does it, so it is left
alone; but it means the resting arm still sways slightly with the idle loop, and a rigid weld cannot track
that. The residual is a couple of degrees, not 61. Raising the pose's priority above `Idle` would make it
stable and fully applied — but `HeldPose`'s header warns every hold angle is solved against that exact pose,
so it is a deliberate follow-up, not a drive-by.

## Three real bugs found and fixed during verification

These are the reason the work took the shape it did. None was in the plan; all three were found by
measuring rather than by reading.

### 1. 🔴 The soldier was silently undressing — 68 of 85 parts gone

Live rig measured **17 parts against the library's 85**. His helmet (39 parts) and plate carrier (30) are
held on by `Anchored = true` and **zero welds**, so the moment `EnemyRig` unanchored everything but the root
they became free bodies, fell off the tower, dropped past `FallenPartsDestroyHeight` and were destroyed by
the engine. Nothing errored, nothing warned, and he still walked, fought and animated — he had just quietly
become a man in a green shirt, which is exactly the "army" identity he was chosen for.

Fixed **generally, in `EnemyRig`** rather than by hand-welding 69 parts in the unversioned place file: loose
nested accessory parts are now welded to their nearest BasePart ancestor before unanchoring. A `Weld`, not a
`WeldConstraint`, because the host is an animated limb — Job #084's "weapon and lamp flys away from boat"
finding. Measured: `WesternBandit`, `Wolf` and `Boar` have **zero** such parts, so nothing else changes.

### 2. 🔴 The launcher pointed at the sky — but only on the client

| | RightHand (rel. root) | Launcher pitch |
|---|---|---|
| Server | `(0.31, 0.01, −0.97)` | **+0.0°**, dot-forward 1.00 |
| Client | `(0.31, 1.60, −0.78)` | **+88.0°**, dot-forward −0.04 |

`InventoryService` solves a held weapon's grip against the live posed hand, and its comment says why that
works: *"the owning client replicates its animated CFrames back"*. **An NPC has no owning client.** The
server-side Animator reports every track at weight 0.00 and holds the rest pose, while each client evaluates
the clip and renders a raised forearm — so a grip solved server-side is solved against a pose no player ever
sees. Exactly the failure `WeaponAssets`' header documents ("both guns aimed ~80° off").

Fixed by removing the idle clip. This rig was published *carrying an M4*, so its authored rest pose already
**is** an arms-forward weapon grip — which is why the server read a perfect +0.0°. Playing a generic Roblox
carry pose on top of it was fighting a pose that was already right. Client and server now agree at +0.0°.

### 3. 🔴 He would have stopped the deep camp re-garrisoning for the whole run

The respawn loop counts "any `CampGuard` within 90 studs of the camp centre". The tower sits ~51 studs out.
So an un-excluded rocket man inflates the count by one forever — and worse, killing him drops the count and
sends a **Bandit up to replace him**, the exact opposite of "kill him once and the tower is yours". He is now
skipped in that count, and is deliberately absent from `garrisons`.

## Not verified

- **Mobile.** Not measured. Worth an emulator pass before this ships: a 60-stud-wide red ring and a
  4-second escape window are a harder ask with a thumbstick than with WASD, and the `mobile` skill is
  emphatic that the Device Emulator answers this rather than reasoning about it. Say the word and I'll ask
  for the emulator.
- **A full run at a later landing.** Everything above was measured at landing 1 (via `ForceFirstCamp`).
  Later landings differ only in the village strength multiplier, which scales his HP and melee like any
  guard's — but it was not observed.

### One measurement worth knowing about

Verification needed **two Play restarts and a client-side reading** because two of the three bugs were
invisible from the server. Notes for anyone testing this again:

- The **server-side Animator on an NPC reports every track at weight 0.00** and holds the rest pose. So
  “what does the rig look like” must be read on the **Client** datamodel, never the Server. That is what
  turned bug 2 from “looks a bit odd in a screenshot” into an exact 88° measurement.
- The run **respawns a parked test character back to the spawn base**, 2,141 studs away, and a watcher
  holding a stale `char` reference then reports “no damage” from an empty field. One test result was
  discarded for exactly this. Re-resolve `plr.Character` every tick and re-anchor it.

## Cost

**+257 BaseParts per live landing site** — tower 128, soldier 85, two chests 44. One or two sites are live at
a time. For scale, a basin's tree ring is already ~350 parts. Levers if a device complains, in order: the
helmet subtree (39 parts), then `KIND.near.tower = false`.

## Deliberately left undone

- **The `fire` animation slot is EMPTY.** It briefly held Defender's `hitAnimation1` as a stand-in recoil,
  but that clip is a *punch* — on the arm holding a 6.5-stud launcher it reads as throwing the weapon.
  GROUND-RULES §4: an empty slot beats a wrong one. Nothing is lost, because the launch is already carried by
  the rocket, the ring, the whistle and the fire sound. **Wanted: a standing shoulder-fire / RPG recoil R15
  clip, ~0.6–1.2 s, one-shot, that moves the torso and not the arms.** Drop the id on one line in
  `EnemyAssets`; nothing else changes.
- **The launcher clips through a tower post** from some angles — a 6.5-stud weapon on a 20-stud deck.
  Cosmetic; it is `CanCollide`/`CanQuery` false so it blocks nothing.
- Findings logged rather than fixed: **0034** (RocketFx builds full blast VFX at any range, and its
  near-blast debounce is now shared between your rocket and his), **0035** (site culling destroys guards
  without `EnemyRig.destroy`, leaking AnimationTracks — pre-existing, worse now), **0036** (one vest trim
  mesh, 4785764674, fails to fetch).

## One open decision

`CampDefs.TOWER.rocketMan.skipFirstLanding` is **`false`** — every landing site gets a rocket man, including
the first. That is the literal ask ("each camp will have one new enemie"), so it is the default; narrowing
your scope is not ours to do. But Job #102 hardcodes landing 1 to 1 near / 2 deep guards for a documented
**onboarding** reason — *"first time players just confused when 2 attack same time"*, "first contact has to
be legible" — and a ranged attacker who opens fire from 160 studs before the player has learned that going
ashore is a thing is squarely inside that concern. One word to flip.

## What you still have to do

1. 🔴 **Save the place.** `ServerStorage.AssetLibrary` is not in git (`sync/ServerStorage` holds only
   `Inventory`), so `AssetLibrary.Enemies.ArmySoldier` — stripped, renamed, with its added `Animator` —
   exists only in the open Studio session. Without a save, every rocket man falls back to a grey box.
2. Review the diff and commit (Claude never commits).
3. Optional: the `fire` animation id above, and the `skipFirstLanding` call.

## Agent use (GROUND-RULES §8)

One independent reviewer, given only the requirement and the repo and **not** the intended approach. It
independently predicted bug 3 (including the replace-him-with-a-Bandit half), the `prop` return value being
discarded, the pad `CanCollide`/`CanQuery` hazard, the need to keep the two blast functions separate, the
tower geometry blocking his own aim ray, and the missing-`Animator` trap — which is what turned the last one
into a one-line asset fix instead of a mystery. It was right to insist `perch` was the wrong mechanism.
