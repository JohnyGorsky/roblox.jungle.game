# Job #084: Playtest bugs — pistol, tied-boat slide, enemy aggro in water, tied-boat retreat

**Project**: `roblox.jungle`
**Created**: 2026-08-16 20:18:03
**Status**: Requirements Gathering (intake)

## Requirements / goal

Five items from the 2026-08-16 playtest: (1) pistol does not fire, (2) player slides on the boat while it is tied at a pier, (3) enemies keep attacking/approaching a tied boat instead of retreating until it is untied, (4) enemies never attack a player who is swimming, (5) no hit feedback on a landed shot - owned by Job 080, cross-referenced here only.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Each item traced to a specific line — see below. **Nothing here is guessed.**
- [x] Open questions answered (wizard) — items 3 and 4 are design calls, not just fixes
      → decisions D1–D4 in [implementation-plan.md](implementation-plan.md), answered 2026-08-16
- [x] Implementation plan created & agreed — [implementation-plan.md](implementation-plan.md)
- [x] Implementation completed — analyzer clean, all 7 scripts synced to the place;
      ⚠️ **Studio playtest outstanding** (see "Still to verify" in the final summary)
- [x] Final summary + changelog written

---

# 1. 🔴 Pistol does not fire

**Where:** `Combat/WeaponServer.server.luau` — `canShoot()` (line ~45) then the ammo gate (~133).

Four things silently return without firing, and **none of them tell the player why**:

| Gate | Returns false when |
|---|---|
| `isDriver(player)` | you are in the `DriverSeat` |
| `hum.SeatPart.Name == "GunSeat"` | you are manning the mounted turret |
| `player:GetAttribute("Busy") == true` | ← **prime suspect** |
| `ammo <= 0` | plays the dry-click, so this one at least has a cue |

⚠️ **`Busy` is set true while CARRYING A CRATE** — `ExcursionServer.pickupLoot` does
`player:SetAttribute("Busy", true)` alongside `char:SetAttribute("Carrying", resource)`. So picking up
loot disarms you until you deposit it. That is very likely what was hit, and it may even be intended
design — but it is **completely unsignalled**, which makes it read as "the pistol is broken".

**Not yet confirmed live** — the play session ended before I could reproduce it. First step is to
reproduce and log which gate returns.

**Ruled out:** the fire path does not use the held item's orientation (it rays from `HumanoidRootPart`
toward the aim point), so Job #079's `holdInChar` change cannot be the cause.

# 2. 🔴 Sliding on the boat while tied at a pier

**Where:** `World/DockServer.server.luau` (~line 234) — `hull.Anchored = true -- greybox hold`.

Tying anchors the hull. ⚠️ The project rule is that the boat carries riders via **Roblox's native
moving-platform carry** (physics-driven, server-owned) and that a manual per-frame carry must never be
added — it causes exactly this class of slide and breaks jumping. An anchored hull is a third case that
was never tested against that rule.

Candidate causes, to be distinguished by test, not by argument:
- the anchored hull no longer participates in the platform carry the player expects
- the player is inside the terrain-water volume and the river current is pushing them
- the `RopeConstraint` added on tie is fighting the assembly

# 3. 🟡 Enemies should retreat while the boat is tied

**Where:** `Enemies/EnemyServer.server.luau` — `applyBite()` (~line 131).

Half of this already works and half does not:

```lua
if victim then            -- a player in bite range: ALWAYS damaged, tied or not
elseif not boat:GetAttribute("Tied") then   -- the BOAT is spared while tied
```

So a tied boat takes no hull damage — but **players still get bitten, and enemies still swim up to the
boat and mill around it**, which is what reads as "they attack even when tied".

⚠️ **This is a DESIGN change, not a bug fix.** The ask — *"enemies retreat once the boat is tied,
allowing you to jump in and start, and only then attack"* — makes the dock a hard safe zone. Needs
deciding before building:
- do they retreat out of sight, or just stop approaching?
- does that make docks a no-risk refuel, removing the tension of a landing?
- does it apply to camp guards on shore too, or only river creatures?

# 4. 🟡 Enemies never attack a swimming player

**Where:** `Enemies/EnemyServer.server.luau` — `tickEnemy()` (~line 158).

⚠️ **`nearestPlayer` is NOT the problem** — checked: it excludes only `Downed` players, so a swimmer is
a perfectly valid bite target.

The actual cause is targeting. Every sea enemy computes its chase against the **BOAT**:

```lua
local boatPos = hull.Position
local dist = (flat distance from the enemy to the BOAT)
local chasing = dist <= def.aggroRadius
... stepToward(enemy, pos, lead, ...)   -- `lead` is the BOAT's predicted position
```

A player swimming away from the boat is therefore never approached. They are only ever bitten if they
happen to be inside `biteRange` when `applyBite` runs — i.e. only if they are next to the boat anyway.

Fix direction: sea enemies should pick the nearest of {boat, any swimming player} as their target.
⚠️ That is a real difficulty change — swimming is currently a safe way to move, and this removes that.

# 5. ↪️ Hit feedback on a landed shot — **owned by Job #080**

Confirmed absent: `grep` for `ParticleEmitter`/`Emit(` across both Combat folders returns nothing.

> ⚠️ **Deliberately NOT duplicated into this job.** Job #080 (hit particles + floating damage numbers)
> already owns it and has the audit and open questions written up. Listed here only so the playtest
> feedback is complete in one place. Build it there.

---

# Already fixed from the same playtest (not part of this job)

- **Enemies vanished instead of falling** — `playOnce("death")` and `despawn()` ran on the same frame.
  `EnemyRig.die` now topples and sinks the body first (measured: 0° → 69°, ~2 studs, over 1.1 s).
- **Health bars** — `makeBar` gave up forever if the model's parts had not replicated yet (no retry), and
  bars were hidden until an enemy was damaged. Both fixed; bars now show when damaged or within 140 studs.
  ⚠️ **Visually unconfirmed**: `screen_capture` does not composite BillboardGuis — proven with a magenta
  control GUI on the player's own head at `MaxDistance 0`, enabled and adorned, absent from the capture.
  Only a human can confirm these now.
- **Hippo scale** — verified applying: **18.33 studs tall, 31.2 long**. If it still reads small it is the
  `sink` (41% shows above water), not the scale.
