# Job #119 — Implementation plan

**Project**: `roblox.jungle` (GAME place, `sync/`) · **Status**: awaiting agreement

Read [intake.md](intake.md) first — it holds the verbatim request and the eleven decisions taken via the
wizard. This document is only *how*.

---

## 0. The one-paragraph shape

A new enemy, `RocketMan`, is spawned once per landing site on the **deep camp's** watchtower, standing on
the `Defender` pad the user placed on the top platform. He never moves. Every 20 s he picks the nearest
player within 160 studs, resolves an impact point with the existing `Ballistics` module, and fires the
existing Bazooka rocket through the existing `RocketLaunched` broadcast — so the red ring, the 4-second
arc, the whistle and the blast all come for free and look identical to the player's own rocket. Get onto
his platform and he stops firing and swings at you instead. Both towers (near and deep) also gain an
`AmmoBox` loot chest on the `InnerPlace` pad.

---

## 1. The single most important design decision: he is a `CampGuard`

He gets the existing **`CampGuard` tag**, plus a new **`RocketMan` attribute**, and `tickGuard` gains one
early branch that hands him to `tickRocketMan` instead.

**Why not a new tag.** The `CampGuard` tag is consumed in seven places outside `ExcursionServer`, and every
one of them is something this enemy needs:

| Consumer | file:line | What he'd lose without the tag |
|---|---|---|
| Handheld hitscan | `Combat/WeaponServer.server.luau:142` | **bullets would pass through him** |
| Boat turret | `Combat/GunServer.server.luau:236` | the mounted gun couldn't hit him |
| Melee | `Combat/MeleeServer.server.luau:147` | the Axe couldn't hit him |
| Player's own rocket | `Combat/Rocket.luau:50` (`TARGET_TAGS`) | you couldn't blast the tower |
| Campfire heal gate | `World/CampfireHeal.server.luau:88` | you could heal with him shooting at you |
| Enemy health bars | `UI/EnemyHealthBars.local.luau:96` | no health bar over him |
| Guard alert pull | `ExcursionServer` `alertNear` | — (harmless either way) |

A new `RocketMan` tag would mean editing all seven and hoping none was missed. One attribute + one branch
edits one loop. ⚠️ And **not** the `Enemy` tag: `EnemyServer.server.luau:584` ticks everything tagged
`Enemy` through the *river-threat* AI, which would try to swim him down the river.

### 1a. Two places that must explicitly EXCLUDE him

Because he wears the guard tag, two existing systems will silently mis-count him:

1. 🔴 **The garrison respawn loop** (`ExcursionServer:2573`) counts every `CampGuard` within
   `GUARD_COUNT_RANGE` = 90 studs of a camp centre to decide whether that camp is short-handed. The tower
   slot is `LAYOUT.tower = {right = -44, forward = -26}` → **51.1 studs** from the camp centre, well inside
   90. So an un-excluded rocket man permanently inflates the deep camp's garrison by one and **suppresses a
   legitimate guard respawn for the whole run**. The count must skip `RocketMan`.
2. **The chase-slot budget** (`campChasers` / `CAMP_MAX_CHASERS`). He never chases, so he must never take a
   slot — otherwise he holds one of the camp's two slots forever and only one real guard can ever come at
   you.

He is also **not** appended to `garrisons` — the same deliberate omission `placeHutBandits` documents,
and what makes decision 7 (no respawn) true by construction rather than by a flag.

---

## 2. Why he never moves, and why that is the robust answer

The user chose "he holds the tower". That is also the only version of this that is safe against
`tickGuard`, and the evidence is already in the file:

- **Y is rewritten every frame.** `tickGuard` re-measures ground height as a guard walks
  (`REMEASURE_STEP`) and sets `footY` from `groundAt`. A guard 36 studs above terrain gets re-seated onto
  the dirt the moment that path runs.
- **The perch mechanism exists and is exactly this problem, already solved once.** `GuardState.perch` /
  `perchModel` (Job #109) hold a hut ambusher at floor height, and the release test is *"is there floor
  under me"* — a 4-stud downward raycast against that one model. Its header records the two failures that
  produced it: a flat 14-stud release radius left a bandit *"6.8 studs out of its doorway still floating
  at floor height"*.
- **There is no pathfinding.** `tickGuard` steers in a straight line (`dir.Unit`), and the rig is
  kinematic (`Anchored`, moved by `PivotTo`), so it passes *through* geometry. A rocket man told to walk to
  a player on the ground would walk through the platform railing, the floor raycast would miss, and he
  would **snap 36 studs down to terrain height in one frame**.

So `tickRocketMan` never calls the movement block at all. He is pinned to the `Defender` pad's world
position and only ever **yaws** to face his target. `perch`/`perchModel` are still set (pointing at the
placed tower clone) so that if any future edit does route him through the movement path, he holds the
platform instead of falling.

---

## 3. Files to change

### 3a. `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` — new def

```
RocketMan = {
  name = "RocketMan",
  category = "land",          -- so EnemyRig's "stand it on its feet" seating applies (EnemyRig:317)
  hp = 110,                   -- decision 10: double a Bandit, because the climb is the fight
  speed = 0,                  -- he never walks. Kept at 0 so a stray movement path is a no-op, not a stroll
  aggroRadius = 160,          -- decision 9
  biteRange = 14,             -- "you reached the platform" — a shade over the Bandit's 12
  biteDamage = 10.8,          -- Bandit-grade; × DAMAGE_SCALE 0.512 = 5.53 in play
  biteCooldown = 1.4,
  size = Vector3.new(4, 5.8, 3),  -- measured: the C3 rig is 4.996 × 5.773 × 2.854
}
```
⚠️ `size` is **not** the Bandit's 5×4×11. That box is the old Panther's and Job #058's crew scaling is
tuned against it — but it is 11 studs deep, and on a 20×20 platform an 11-deep hitbox overhangs the
railing on both sides. He is a new enemy with no #058 history, so he gets an honest box.

⚠️ `strengthFor` is **not** applied to camp-guard bites (the file says so explicitly), so his melee is flat
day and night. Left that way deliberately — consistency with the guards beside him.

### 3b. `sync/ServerScriptService/Enemies/EnemyAssets.luau` — new art entry

```
RocketMan = {
  model = "ArmySoldier",   -- resolved by NAME across AssetLibrary groups
  scale = nil,             -- 5.77 studs tall is already right (same call as the Bandit)
  yawOffset = 0,           -- measured: the rig's HumanoidRootPart LookVector is (0,0,-1) at identity = our forward
  eyes = false,            -- 🔴 he is a person. Same reason the Bandit opts out (EnemyAssets' own note)
  anim = { ... }, sound = { ... }  -- see §4
}
```

### 3c. `sync/ServerScriptService/Combat/Rocket.luau` — an enemy launch path

`Rocket.launchEnemy(origin, impact, def)` plus a **separate** `enemyBlast`.

🔴 **Why this goes in `Rocket.luau` and not a new module.** The `RocketLaunched` RemoteEvent is *created*
here (`Instance.new` → `ReplicatedStorage`). A second module creating one would give the client two
remotes and half the rockets would go undrawn; a second module `WaitForChild`-ing it introduces a
server-module load-order dependency for no benefit. One file owns the rocket.

🔴 **Why the two blasts stay two functions and must never be merged.** `Rocket.luau`'s header is emphatic
that the player's blast is tag-restricted *by construction* so it can never hit a player, a crewmate or the
boat, and that a "skip players" filter is the version a later edit silently breaks. The enemy blast wants
the opposite (decision 5: players, boat, **and** friendly fire). Merging them behind a boolean is exactly
how the player's rocket eventually learns to kill the crew. So:

| | `blast` (player-fired) | `enemyBlast` (rocket-man-fired) |
|---|---|---|
| Players | never | **yes** — `HP` attribute on the character Model |
| The boat | never | **yes** — `Workspace.Boat`'s `HP` attribute |
| `Enemy`/`CampGuard`/`Generator` | yes | **yes** (friendly fire) |
| `KillReward` | credited to the shooter | **none** — nobody fired it |

The `KillReward` omission is not just tidiness: without it, baiting a shell onto the garrison would pay the
player salvage for kills the tower made.

Both share `Ballistics.blastFactor`, so the falloff curve and the ring the player sees stay one calculation.

**Player damage must respect two existing guards**, or it re-opens a bug Job #103 already fixed:
- skip a character whose `Downed` attribute is set (it is already out of the fight);
- skip while `Workspace:GetServerTimeNow() < char.InvincibleUntil` — the post-revive grace. `tickGuard`'s
  bite comments say plainly there is **no single chokepoint** for player damage and every site that
  writes a player's `HP` must re-check this.

**Every target is found at impact time, never captured at launch** — the same rule the existing `blast`
documents, for the same reason (4 s is long enough for a landing site to be culled).

Numbers (decision 6): `blastDamage = 40`, `blastRadius = 30`, `blastInner = 0.5`, `blastMinFactor = 0.25`
→ 40 across the inner 15 studs, falling to 10 at the rim. `flightTime = 4.0`.

### 3d. `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` — the bulk

1. `spawnRocketMan(padPos, towerModel, parent, strength)` — builds through `EnemyRig.build` like every
   other guard, tags `CampGuard`, sets the `RocketMan` attribute, seats him on the pad, records
   `perch`/`perchModel` against the tower clone, sets `aggroRadius = 160`, and does **not** touch
   `garrisons`.
2. `tickRocketMan(guard, dt, st)` — the behaviour, see §5.
3. One early branch at the top of `tickGuard`.
4. The two exclusions from §1a.
5. Tower placement: `KIND.deep.tower = true`; after `prop()` places a tower, find `Tower.Defender` and
   `Tower.InnerPlace` in the clone, **set both `CanCollide = false` and `CanQuery = false`**, then place the
   chest, and (deep camp only) the rocket man.

   🔴 **The `CanCollide` fix is not cosmetic.** `prop()` applies `d.CanCollide = o.collide == true` to
   *every* BasePart in the clone (`ExcursionServer:427`), and the tower is placed with `collide = true`.
   So as shipped, the user's two invisible marker pads become **invisible collidable slabs** on the
   platform. `CanQuery` matters independently: `GroundRing`'s header lists four unrelated systems that a
   stray queryable part breaks, including `HudState`'s 8-stud "am I aboard?" ray.

6. The chest: clone `AmmoBox` from the library, position it **on the pad**, and give it
   `Kind = "Salvage"` / `Amount = 45..70` + `lootPrompt(crate, "Search")`.

   ⚠️ It must **not** go through `prop()`. `prop()` ends with `FoliageDefs.seatOnGround(clone, groundAt(x, z))`
   — it would drop the chest 36 studs down onto the terrain under the tower. A separate `placeOnPad` helper
   sits it on the platform by its own measured bounding box instead.

### 3e. `sync/ServerScriptService/World/CampDefs.luau` — the numbers

`KIND.deep.tower = true`, and a new `CampDefs.TOWER` table holding the pad names, the chest model/salvage
range/scale, the fire interval, the minimum fire range and the melee range — so every tunable in this
feature is in the dressing table, not in the server script, which is the contract `CampDefs`' own header
sets out.

---

## 4. Animations and sounds — all reused, nothing sourced (decision 11)

Every id below is already owned and already proven on an R15 rig in this game. `EnemyRig` loads them onto
an `AnimationController` + `Animator` — and it already knows to **reuse the rig's own Animator** when the
model ships one, because "adding a second Animator alongside it silently plays nothing"
(`EnemyRig:401-403`). C3 ships a `Humanoid`, so that path is the one that runs.

| Slot | Id | Where it comes from | Reads as |
|---|---|---|---|
| `idle` | `507768375` | `ItemDefs.HOLD_ANIM` — the player's own tool-hold pose | launcher up on the shoulder, watching |
| `attack` | `567480700` | Defender's `axeSlash` 1 (via `WeaponAssets.ART.Axe`) | close-combat swing A |
| `attack2` | `567479941` | Defender's `axeSlash` 2 | close-combat swing B |
| `fire` | `80792212061667` | Defender's `hitAnimation1` (the Bandit's attack) | the shoulder jolt as the rocket leaves |
| `move` | — | *deliberately unset* | he never walks |
| `death` | — | *deliberately unset* | the Bandit has none either |

`attack`/`attack2` **alternate per swing**, the way `MeleeServer` alternates the player's two slashes
"so repeated swings do not look canned". This is the requirement-6 deliverable: his close combat is two
distinct visible swings, not one repeated pose.

Sounds: the Bandit's bundled set (`aggro` `1454256125`, `attack` `6108540937`, `hurt` `9125652432`,
`death` `9125652949`) — a human raider's voice on a human raider. His own 11 bundled sounds are all *gun
mechanism* noises attached to the M4 that gets stripped (§6), so they leave with it.

**The one slot worth improving later**: `fire`. A shoulder-fired launcher deserves a real firing pose, and
`hitAnimation1` is a reuse rather than the right clip. The table above is written so it is a one-line id
swap. If you want to source it: search Roblox's animation catalog / the Studio animation editor for a
*standing rifle/RPG fire* or *shoulder-fire recoil* R15 clip, ~0.6–1.2 s, one-shot (not looped), and hand
me the id.

---

## 5. `tickRocketMan` — the behaviour, step by step

Runs on `Heartbeat` like every guard, in place of `tickGuard`'s body.

1. **Hold position.** Never write X/Z. Yaw only: `PivotTo(CFrame.lookAt(anchor, anchor + flatDirToTarget))`
   with Y pinned to the seated perch height.
2. **Pick a target.** Nearest player character within `aggroRadius` (160) that is alive and not `Downed`.
   Same test `tickGuard` uses, so a downed crewmate stops drawing fire.
3. **Line of sight**, cast from his muzzle to the target, **excluding `Workspace.Foliage`** — the exact
   exclusion `Ballistics.impactParams` documents as a *fix, not a shortcut* (findings/0023): foliage is
   `CanQuery`, and with Instance Streaming the client often hasn't loaded ferns the server has. Without
   this he refuses to fire at a player standing behind a bush that only the server can see.
4. **Melee band** — target within `biteRange` (14) in 3D, i.e. they are on the platform with him:
   - stop firing entirely (the 20 s timer is *held*, not reset, so leaving doesn't buy a fresh cycle);
   - swing on `biteCooldown` (1.4 s), alternating `attack`/`attack2` + the attack sound;
   - damage the character's `HP`, gated on `InvincibleUntil`, `× DAMAGE_SCALE`.
5. **Fire band** — target beyond melee, inside 160, LOS clear, **and beyond `MIN_FIRE_RANGE`**:
   - 🔴 `MIN_FIRE_RANGE = 48`. The blast radius is 30. Without a floor he shells the foot of his own tower,
     and his own model — which he wears the `CampGuard` tag for — is in friendly-fire range of it. 48 puts
     the crater's rim clear of the tower base.
   - every `FIRE_INTERVAL = 20` s: `Ballistics.resolveImpact(muzzle, targetPos, range = 300, ignore = {his own model, the tower})`, then `Rocket.launchEnemy(muzzle, impact, def)`, then `EnemyRig.playOnce(guard, "fire")` + a fire sound.
   - He aims at **where the player is at launch**, with no lead. That is what makes decision 4's "escape
     the red circle" a real mechanic: a walking player covers 64 studs in the 4 s flight against a 30-stud
     radius, so moving *at all* is enough, and standing still is what gets punished.
6. **Aggro roar** once on acquiring a target, cleared when he loses it — the `st.roared` pattern already in
   `tickGuard`, so the player gets an audible "he has seen you" before the first shell.

---

## 6. Asset work in Studio (needs you to SAVE the place)

`ServerStorage.AssetLibrary` is **not** in git (`sync/ServerStorage` contains only `Inventory`), so this
half lives in the `.rbxl` and I cannot commit it. I'll do the edits over MCP; **the place must be saved by
you** or the model vanishes on next open and every rocket man falls back to a grey box.

The model as inserted is 122 parts, and 37 of them are a rifle:

| Subtree | Parts | Action |
|---|---|---|
| body (16 R15 MeshParts + `HumanoidRootPart`) | 16 | keep |
| `Head > Model` — helmet, goggles, NVG mount | 39 | **keep** — this is most of what makes him read as "army" |
| `UpperTorso > Model` — plate carrier + pouches | 30 | **keep** |
| `RightHand > "Mk18 EoTech"` — M4 carbine | 37 | 🔴 **strip** — he carries a Bazooka, not an M4. Takes the model to **85 parts** and removes the `ProjectorSight` `SurfaceGui` and all 11 gun sounds with it |

Then: rename the inner model (it is currently named `" "` — a single space) to `ArmySoldier`, drop the
wrapper, and file it at `ServerStorage.AssetLibrary.Enemies.ArmySoldier`. **Script scan: 0 scripts**,
already verified on the live insert — nothing to delete, and nothing to fear from Play.

**The Bazooka in his hand.** `AssetLibrary.Weapons.Bazooka` is the same MeshPart the player carries. The
rig has a `RightGripAttachment` on `RightHand` (verified present), so the launcher welds to that rather
than to a computed offset. Scale and orientation come straight from `WeaponAssets.ART.Bazooka`, whose
header records that the muzzle is **+X** and up is **+Y**, *measured two independent ways* — so I do not
re-derive it, and the `holdInChar = BARREL_FORWARD` / `gripOffset = (-0.5, -0.30, 0)` values are reused as
authored.

⚠️ The 6.50-stud launcher on a 5.77-stud rig will need its grip checked **on screen** once, not trusted
from the numbers — `WeaponAssets`' header records three separate occasions when a weapon's orientation was
guessed wrong, and its `gripOffset` notes are explicit that the offset is in absolute studs applied after
scaling.

Registry: log the asset in `roblox.workspace/Assets/registry/models.md` and in the game's `ASSETS.md`
(id `11927692797`, free, Creator Store, 0 scripts, what was stripped and why).

---

## 7. Perf budget, stated plainly

Per landing site this job adds: **+1 RangerTower (128 parts)** at the deep camp, **+1 rocket man (85
parts)**, **+2 AmmoBox chests (44 parts)** = **+257 parts per live site**. One or two sites are live at a
time, so the ceiling is ~514 parts. For scale, `CampDefs.CLEARING` already spends ~350 parts on the tree
ring of a single basin. If a real device complains, the lever in order is: the helmet subtree (39 parts),
then `KIND.near.tower = false` (which is the option you declined for looks, and can be flipped back in one
edit).

---

## 8. Verification — in Play, at the player's camera (GROUND-RULES §7)

Not one of these is signed off from Edit. Each names what failure looks like, because a check that cannot
fail is decoration (GROUND-RULES §7).

| # | Check | Passes when | **Fails when** |
|---|---|---|---|
| 1 | He is on the platform | screenshot from the ground shows him at the rail, feet on the floor | he is floating, sunk into the deck, or standing on the terrain 36 studs below |
| 2 | He holds the launcher | screenshot from the platform shows the Bazooka in his right hand, muzzle forward | it is inside his chest, pointing at his own head, or lying flat along the forearm |
| 3 | He fires on time | server log shows a launch ~every 20 s while a player is in range | he fires every frame, never, or on a drifting interval |
| 4 | The ring is honest | the red ring appears at launch and the blast goes off **at the ring** | the ring is somewhere the explosion is not (the `Ballistics` failure mode) |
| 5 | 40 / 10 damage | player at the centre loses 40 HP; at the rim, 10 | any other number — especially 300, which would mean the *player's* blast values leaked in |
| 6 | The circle is escapable | walk out of the ring during the 4 s and take **zero** | you cannot clear it, or you take damage having left |
| 7 | Friendly fire | a shell landing on camp guards damages them, and pays the player **nothing** | salvage/XP arrives for a kill the tower made |
| 8 | The boat takes it | a shell on the moored boat drops the hull's `HP` | the hull is untouched |
| 9 | Post-revive grace | revive inside a live crater → no damage until the window closes | you are re-downed on the frame you stand up (the Job #103 bug) |
| 10 | Close combat | on the platform he stops firing and swings, visibly, alternating two animations | he keeps shelling from 5 studs away, or swings with no animation |
| 11 | He doesn't shell himself | no launch while the target is inside 48 studs | his own HP drops after his own shot |
| 12 | Killable, and stays dead | he dies to gunfire/melee and never returns | he respawns on the garrison timer |
| 13 | 🔴 Guards still respawn | after clearing the deep camp with the rocket man alive, guards return in 2–3 min | they never return — the §1a garrison mis-count |
| 14 | Chests on both towers | `Search` prompt on both platforms, 45–70 salvage | the chest is on the terrain below, or only the deep tower has one |
| 15 | The pads are intangible | you can walk over both pads freely | you trip on an invisible slab (the §3d.5 `CanCollide` bug) |
| 16 | Analyzer clean | `bash tools/luau-analyze.sh <each changed file>` reports nothing new | any new diagnostic |

An **independent reviewer agent** has been run against the requirement without being told this approach
(GROUND-RULES §8); its findings are folded in before implementation starts.

---

## 9. What I need from you

1. **Agreement on this plan** (GROUND-RULES §5 — implementation does not start before that).
2. **Save the place** after I do the §6 asset work, or the model is lost.
3. Optional, later: a real *shoulder-fire* R15 animation id for the `fire` slot (§4).
